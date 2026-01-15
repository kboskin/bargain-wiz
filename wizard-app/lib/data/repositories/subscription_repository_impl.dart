import 'dart:async';
import 'dart:io' show Platform;
import 'package:dartz/dartz.dart';
import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/core/services/subscription/payment_provider.dart';
import 'package:appwizard/core/services/subscription/subscription_sync_service.dart';
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/data/datasources/subscription_in_memory_datasource.dart';
import 'package:appwizard/data/models/subscription_model.dart';
import 'package:appwizard/data/models/remote_config/subscription_config.dart';
import 'package:appwizard/domain/repositories/subscription_repository.dart';
import 'package:appwizard/domain/entities/subscription_product.dart';
import 'package:appwizard/domain/entities/subscription_status.dart';
import 'package:appwizard/domain/entities/subscription_tier.dart';

/// Implementation of SubscriptionRepository
class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final PaymentProvider _paymentProvider;
  final SubscriptionSyncService _syncService;
  final SubscriptionInMemoryDataSource _inMemoryDataSource;
  final RemoteConfigService _remoteConfigService;
  final AppLogger _logger;

  SubscriptionRepositoryImpl(
    this._paymentProvider,
    this._syncService,
    this._inMemoryDataSource,
    this._remoteConfigService,
    this._logger,
  );

  @override
  Future<Either<Failure, List<SubscriptionProduct>>> getAvailableProducts() async {
    try {
      _logger.i('Loading available subscription products');

      // 1. Load subscription config from Remote Config
      final config = await _remoteConfigService.getSubscriptionConfig();
      if (config == null || config.products.isEmpty) {
        _logger.w('Subscription config not available, using fallback product IDs');
        return _loadHardcodedProducts();
      }

      // 2. Extract platform-specific product IDs
      final productIds = config.products
          .map((p) => Platform.isIOS ? p.productId.ios : p.productId.android)
          .where((id) => id.isNotEmpty)
          .toList();

      if (productIds.isEmpty) {
        _logger.w('No product IDs found in config');
        return _loadHardcodedProducts();
      }

      // 3. Query store for product details (pricing, currency)
      final storeProducts = await _paymentProvider.loadProducts(productIds);

      // 4. Combine Remote Config metadata with store pricing
      final combinedProducts = <SubscriptionProduct>[];

      for (final configProduct in config.products) {
        final productId = Platform.isIOS
            ? configProduct.productId.ios
            : configProduct.productId.android;

        if (productId.isEmpty) continue;

        final storeProduct = storeProducts.firstWhere(
          (sp) => sp.productId == productId,
          orElse: () => StoreProduct(productId: productId),
        );

        // Get multilocale title/description or use string
        final title = _getMultilocaleText(configProduct.title, 'en');
        final description = _getMultilocaleText(configProduct.description, 'en');

        combinedProducts.add(SubscriptionProduct(
          productId: storeProduct.productId,
          tier: configProduct.tierEnum,
          title: title,
          description: description,
          price: storeProduct.price,
          currency: storeProduct.currency,
          features: configProduct.features,
          displayOrder: configProduct.displayOrder,
        ));
      }

      // 5. Sort by display order
      combinedProducts.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

      _logger.i('Loaded ${combinedProducts.length} subscription products');
      return Right(combinedProducts);
    } catch (e, stackTrace) {
      _logger.e('Error loading products', e, stackTrace);
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> purchaseSubscription(String productId) async {
    try {
      _logger.i('Initiating purchase for product: $productId');

      // 1. Initiate purchase through payment provider
      final result = await _paymentProvider.purchaseProduct(productId);

      if (!result.success) {
        return Left(ServerFailure(
          result.errorMessage ?? 'Purchase failed',
        ));
      }

      // 2. Wait for purchase to complete via purchase stream
      // The purchase details will come through the purchaseUpdates stream
      // For now, we'll use a timeout and listen to the stream
      PurchaseDetails? purchaseDetails;
      final completer = Completer<PurchaseDetails?>();
      final subscription = _paymentProvider.purchaseUpdates.listen(
        (update) {
          if (update.type == PurchaseUpdateType.success &&
              update.purchaseDetails?.productId == productId) {
            purchaseDetails = update.purchaseDetails;
            if (!completer.isCompleted) {
              completer.complete(update.purchaseDetails);
            }
          } else if (update.type == PurchaseUpdateType.error) {
            if (!completer.isCompleted) {
              completer.completeError(update.error ?? 'Purchase failed');
            }
          }
        },
      );

      try {
        purchaseDetails = await completer.future.timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            throw TimeoutException('Purchase timeout');
          },
        );
      } finally {
        await subscription.cancel();
      }

      if (purchaseDetails == null) {
        return Left(ServerFailure('Purchase details not received'));
      }

      // 3. Verify purchase with backend
      final verifiedStatus = await _syncService.verifyAndSyncReceipt(
        purchaseDetails!,
      );

      if (verifiedStatus == null) {
        return Left(ServerFailure('Failed to verify purchase with backend'));
      }

      // 4. Update in-memory cache
      final model = SubscriptionModel.fromEntity(verifiedStatus);
      _inMemoryDataSource.saveSubscriptionStatus(model);

      _logger.i('Purchase completed and synced to backend');
      return const Right(null);
    } on TimeoutException {
      _logger.e('Purchase timeout');
      return Left(ServerFailure('Purchase timeout'));
    } catch (e, stackTrace) {
      _logger.e('Error purchasing subscription', e, stackTrace);
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, SubscriptionStatus?>> getSubscriptionStatus() async {
    try {
      // 1. Check in-memory cache first
      final cached = _inMemoryDataSource.getSubscriptionStatus();
      if (cached != null) {
        _logger.i('Returning subscription status from cache');
        return Right(cached.toEntity());
      }

      // 2. Fetch from backend
      _logger.i('Fetching subscription status from backend');
      final status = await _syncService.fetchFromBackend();

      if (status != null) {
        // Store in cache
        final model = SubscriptionModel.fromEntity(status);
        _inMemoryDataSource.saveSubscriptionStatus(model);
      }

      return Right(status);
    } catch (e, stackTrace) {
      _logger.e('Error getting subscription status', e, stackTrace);
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> restorePurchases() async {
    try {
      _logger.i('Restoring purchases...');

      // 1. Restore purchases from store
      final purchases = await _paymentProvider.restorePurchases();

      if (purchases.isEmpty) {
        _logger.i('No purchases to restore');
        return const Right(null);
      }

      // 2. Sync each purchase with backend
      for (final purchase in purchases) {
        final verifiedStatus = await _syncService.verifyAndSyncReceipt(purchase);
        if (verifiedStatus != null) {
          final model = SubscriptionModel.fromEntity(verifiedStatus);
          _inMemoryDataSource.saveSubscriptionStatus(model);
        }
      }

      _logger.i('Purchases restored and synced to backend');
      return const Right(null);
    } catch (e, stackTrace) {
      _logger.e('Error restoring purchases', e, stackTrace);
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Fallback: Load hardcoded products if Remote Config unavailable
  Future<Either<Failure, List<SubscriptionProduct>>> _loadHardcodedProducts() async {
    final productIds = [
      'com.bargain.wiz.basic',
      'com.bargain.wiz.premium',
    ];

    final storeProducts = await _paymentProvider.loadProducts(productIds);

    final products = storeProducts.map((sp) {
      SubscriptionTier tier;
      if (sp.productId.contains('premium')) {
        tier = SubscriptionTier.premium;
      } else if (sp.productId.contains('basic')) {
        tier = SubscriptionTier.basic;
      } else {
        tier = SubscriptionTier.free;
      }

      return SubscriptionProduct(
        productId: sp.productId,
        tier: tier,
        title: sp.title ?? tier.name.toUpperCase(),
        description: sp.description ?? 'Subscription tier',
        price: sp.price,
        currency: sp.currency,
        features: [],
        displayOrder: tier == SubscriptionTier.basic ? 1 : 2,
      );
    }).toList();

    return Right(products);
  }

  /// Extract text from multilocale map or return string
  String _getMultilocaleText(dynamic text, String locale) {
    if (text is String) {
      return text;
    } else if (text is Map<String, dynamic>) {
      return text[locale] as String? ?? text['en'] as String? ?? '';
    }
    return '';
  }
}
