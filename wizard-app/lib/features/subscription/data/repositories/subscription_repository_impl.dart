import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dartz/dartz.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:appwizard/core/config/prefs_keys.dart';
import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/services/subscription/payment_provider.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/subscription/data/datasources/subscription_in_memory_datasource.dart';
import 'package:appwizard/features/subscription/data/models/subscription_model.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_product.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_status.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';
import 'package:appwizard/features/subscription/domain/repositories/subscription_repository.dart';

/// Store-SDK-only subscriptions: no backend, no receipt server.
///
/// The entitlement ("what am I paying for") is derived from the purchase the store reports
/// (`in_app_purchase` purchase stream, initial purchase or restore): product id → tier via
/// `subscription_config`. It is kept in memory and in `SharedPreferences` so the tier is
/// known offline and at cold start. **Restore Purchases** re-reads the store and drops the
/// entitlement only when the store reports no active purchase, so a lapsed subscription
/// falls back to free without a flicker on slow stores. Server-side receipt verification can
/// be added later behind [PaymentProvider] without touching callers.
class SubscriptionRepositoryImpl implements SubscriptionRepository {
  SubscriptionRepositoryImpl(
    this._paymentProvider,
    this._inMemoryDataSource,
    this._remoteConfigService,
    this._prefs,
    this._logger, {
    Duration restoreWindow = const Duration(seconds: 5),
  }) : _restoreWindow = restoreWindow {
    // The store stream only flows once the provider is initialised, and nothing else does it.
    unawaited(_initialiseProvider());
    // Purchases and restores also arrive when this app did not initiate them (other
    // device, renewal, pending → purchased), so always listen.
    try {
      _updates = _paymentProvider.purchaseUpdates.listen(
        _onPurchaseUpdate,
        onError: (Object e) => _logger.w('Purchase stream error: $e'),
      );
    } on Object catch (e) {
      _logger.w('Purchase stream unavailable: $e');
    }
  }

  static const Duration purchaseTimeout = Duration(seconds: 60);

  final PaymentProvider _paymentProvider;
  final SubscriptionInMemoryDataSource _inMemoryDataSource;
  final RemoteConfigService _remoteConfigService;
  final SharedPreferences _prefs;
  final AppLogger _logger;

  /// How long Restore Purchases waits for the store to replay purchases on the stream.
  final Duration _restoreWindow;

  StreamSubscription<PurchaseUpdate>? _updates;

  Future<void> _initialiseProvider() async {
    try {
      final ready = await _paymentProvider.initialize();
      if (!ready) _logger.w('Payment provider is not available on this device');
    } on Object catch (e) {
      _logger.w('Payment provider initialisation failed: $e');
    }
  }

  void _onPurchaseUpdate(PurchaseUpdate update) {
    final details = update.purchaseDetails;
    if (update.type != PurchaseUpdateType.success || details == null) return;
    _remember(statusFor(details));
  }

  /// Tier for a store product id: `subscription_config` first, then the id's naming.
  SubscriptionTier tierForProduct(String productId) {
    final config = _remoteConfigService.getSubscriptionConfig();
    for (final product in config?.products ?? const []) {
      if (product.productId.ios == productId || product.productId.android == productId) {
        return product.tierEnum;
      }
    }
    if (productId.contains('premium')) return SubscriptionTier.premium;
    if (productId.contains('basic')) return SubscriptionTier.basic;
    return SubscriptionTier.free;
  }

  /// Entitlement implied by a store purchase (active while the store keeps reporting it).
  SubscriptionStatus statusFor(PurchaseDetails purchase) {
    final tier = tierForProduct(purchase.productId);
    return SubscriptionStatus(
      tier: tier,
      isActive: tier != SubscriptionTier.free,
      productId: purchase.productId,
      transactionId: purchase.transactionId,
      originalTransactionId: purchase.originalTransactionId,
      platform: purchase.platform,
    );
  }

  void _remember(SubscriptionStatus status) {
    final model = SubscriptionModel.fromEntity(status);
    _inMemoryDataSource.saveSubscriptionStatus(model);
    _prefs.setString(PrefsKeys.subscriptionStatus, jsonEncode(model.toJson()));
    _logger.i('Subscription: ${status.tier.name} via ${status.productId}');
  }

  void _forget() {
    _inMemoryDataSource.clearSubscriptionStatus();
    _prefs.remove(PrefsKeys.subscriptionStatus);
  }

  SubscriptionModel? _persisted() {
    final raw = _prefs.getString(PrefsKeys.subscriptionStatus);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? SubscriptionModel.fromJson(decoded) : null;
    } on Object {
      return null;
    }
  }

  @override
  Future<Either<Failure, List<SubscriptionProduct>>> getAvailableProducts() async {
    try {
      _logger.i('Loading available subscription products');
      final config = _remoteConfigService.getSubscriptionConfig();
      if (config == null || config.products.isEmpty) {
        _logger.w('Subscription config not available, using fallback product IDs');
        return _loadHardcodedProducts();
      }
      final productIds = config.products
          .map((p) => Platform.isIOS ? p.productId.ios : p.productId.android)
          .where((id) => id.isNotEmpty)
          .toList();
      if (productIds.isEmpty) return _loadHardcodedProducts();

      final storeProducts = await _paymentProvider.loadProducts(productIds);
      final combined = <SubscriptionProduct>[];
      for (final configProduct in config.products) {
        final productId = Platform.isIOS ? configProduct.productId.ios : configProduct.productId.android;
        if (productId.isEmpty) continue;
        final storeProduct = storeProducts.firstWhere(
          (sp) => sp.productId == productId,
          orElse: () => StoreProduct(productId: productId),
        );
        combined.add(SubscriptionProduct(
          productId: storeProduct.productId,
          tier: configProduct.tierEnum,
          title: _getMultilocaleText(configProduct.title, 'en'),
          description: _getMultilocaleText(configProduct.description, 'en'),
          price: storeProduct.price,
          currency: storeProduct.currency,
          features: configProduct.features,
          displayOrder: configProduct.displayOrder,
        ));
      }
      combined.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      return Right(combined);
    } catch (e, stackTrace) {
      _logger.e('Error loading products', e, stackTrace);
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> purchaseSubscription(String productId) async {
    try {
      _logger.i('Initiating purchase for product: $productId');
      // Listen before initiating so a fast store confirmation is never missed.
      final completer = Completer<PurchaseDetails>();
      final sub = _paymentProvider.purchaseUpdates.listen((update) {
        if (completer.isCompleted) return;
        if (update.type == PurchaseUpdateType.success && update.purchaseDetails?.productId == productId) {
          completer.complete(update.purchaseDetails);
        } else if (update.type == PurchaseUpdateType.error) {
          completer.completeError(StateError(update.error ?? 'Purchase failed'));
        } else if (update.type == PurchaseUpdateType.cancelled) {
          completer.completeError(StateError('Purchase cancelled'));
        }
      });
      try {
        final result = await _paymentProvider.purchaseProduct(productId);
        if (!result.success) {
          return Left(ServerFailure(result.errorMessage ?? 'Purchase failed'));
        }
        final details = await completer.future.timeout(purchaseTimeout);
        _remember(statusFor(details));
        return const Right(null);
      } finally {
        await sub.cancel();
      }
    } on TimeoutException {
      _logger.e('Purchase timeout');
      return const Left(ServerFailure('Purchase timeout'));
    } catch (e, stackTrace) {
      _logger.e('Error purchasing subscription', e, stackTrace);
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, SubscriptionStatus?>> getSubscriptionStatus() async {
    try {
      final cached = _inMemoryDataSource.getSubscriptionStatus();
      if (cached != null) return Right(cached.toEntity());
      final persisted = _persisted();
      if (persisted != null) {
        _inMemoryDataSource.saveSubscriptionStatus(persisted);
        return Right(persisted.toEntity());
      }
      return const Right(null); // never purchased on this device → free
    } catch (e, stackTrace) {
      _logger.e('Error getting subscription status', e, stackTrace);
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> restorePurchases() async {
    try {
      _logger.i('Restoring purchases...');
      final restored = <PurchaseDetails>[];
      final sub = _paymentProvider.purchaseUpdates.listen((update) {
        if (update.type == PurchaseUpdateType.success && update.purchaseDetails != null) {
          restored.add(update.purchaseDetails!);
        }
      });
      try {
        restored.addAll(await _paymentProvider.restorePurchases());
        // Stores deliver restored purchases on the stream shortly after the call.
        await Future<void>.delayed(_restoreWindow);
      } finally {
        await sub.cancel();
      }
      if (restored.isEmpty) {
        // The store reports no active purchase: the subscription lapsed (or never existed).
        _logger.i('No purchases to restore; clearing the stored entitlement');
        _forget();
        return const Right(null);
      }
      // Highest tier wins when several purchases are reported.
      final best = restored.map(statusFor).reduce((a, b) => b.tier.index > a.tier.index ? b : a);
      _remember(best);
      return const Right(null);
    } catch (e, stackTrace) {
      _logger.e('Error restoring purchases', e, stackTrace);
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Fallback: hardcoded products if Remote Config is unavailable.
  Future<Either<Failure, List<SubscriptionProduct>>> _loadHardcodedProducts() async {
    const productIds = ['com.bargain.wiz.basic', 'com.bargain.wiz.premium'];
    final storeProducts = await _paymentProvider.loadProducts(productIds);
    final products = storeProducts.map((sp) {
      final tier = tierForProduct(sp.productId);
      return SubscriptionProduct(
        productId: sp.productId,
        tier: tier,
        title: sp.title ?? tier.name.toUpperCase(),
        description: sp.description ?? 'Subscription tier',
        price: sp.price,
        currency: sp.currency,
        features: const [],
        displayOrder: tier == SubscriptionTier.basic ? 1 : 2,
      );
    }).toList();
    return Right(products);
  }

  String _getMultilocaleText(dynamic text, String locale) {
    if (text is String) return text;
    if (text is Map) return text[locale] as String? ?? text['en'] as String? ?? '';
    return '';
  }

  /// Stops listening to the store stream (tests / hot restart).
  Future<void> dispose() async => _updates?.cancel();
}
