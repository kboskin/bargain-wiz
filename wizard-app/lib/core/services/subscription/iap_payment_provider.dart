import 'dart:async';
import 'dart:io' show Platform;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:appwizard/core/services/subscription/payment_provider.dart';
import 'package:appwizard/core/utils/app_logger.dart';

/// IAP Payment Provider implementation using in_app_purchase package
class IAPPaymentProvider extends PaymentProvider {
  final InAppPurchase _iap = InAppPurchase.instance;
  final StreamController<PurchaseUpdate> _purchaseUpdateController =
      StreamController<PurchaseUpdate>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _isInitialized = false;

  IAPPaymentProvider(super.logger);

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      logger.i('Initializing IAP Payment Provider...');

      // Check if IAP is available
      final available = await _iap.isAvailable();
      if (!available) {
        logger.w('IAP is not available on this device');
        return false;
      }

      // Listen to purchase updates
      _purchaseSubscription = _iap.purchaseStream.listen(
        (purchaseDetailsList) {
          _handlePurchaseUpdates(purchaseDetailsList);
        },
        onDone: () {
          _purchaseUpdateController.close();
        },
        onError: (error) {
          logger.e('Purchase stream error', error);
          _purchaseUpdateController.add(
            PurchaseUpdate.error(error.toString()),
          );
        },
      );

      _isInitialized = true;
      logger.i('IAP Payment Provider initialized');
      return true;
    } catch (e, stackTrace) {
      logger.e('Error initializing IAP Payment Provider', e, stackTrace);
      return false;
    }
  }

  @override
  Future<List<StoreProduct>> loadProducts(List<String> productIds) async {
    try {
      logger.i('Loading products: $productIds');

      final response = await _iap.queryProductDetails(productIds);

      if (response.notFoundIDs.isNotEmpty) {
        logger.w('Products not found: ${response.notFoundIDs}');
      }

      return response.productDetails.map((product) {
        return StoreProduct(
          productId: product.id,
          price: product.price,
          currency: product.currencyCode,
          description: product.description,
          title: product.title,
        );
      }).toList();
    } catch (e, stackTrace) {
      logger.e('Error loading products', e, stackTrace);
      return [];
    }
  }

  @override
  Future<PurchaseResult> purchaseProduct(String productId) async {
    try {
      logger.i('Initiating purchase for product: $productId');

      // Get product details first
      final response = await _iap.queryProductDetails({productId});
      if (response.productDetails.isEmpty) {
        return PurchaseResult.failure('Product not found: $productId');
      }

      final productDetails = response.productDetails.first;
      final purchaseParam = PurchaseParam(productDetails: productDetails);

      // Initiate purchase (non-consumable for subscriptions)
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);

      // Purchase result will come through purchaseUpdates stream
      // The repository will listen to the stream for the actual result
      // For now, return a pending result - actual details come via stream
      return PurchaseResult.success(
        PurchaseDetails(
          productId: productId,
          transactionId: 'pending', // Will be set from purchase stream
          transactionDate: DateTime.now(),
          receiptData: 'pending', // Will be set from purchase stream
          platform: Platform.isIOS ? 'ios' : 'android',
        ),
      );
    } catch (e, stackTrace) {
      logger.e('Error purchasing product', e, stackTrace);
      return PurchaseResult.failure(e.toString());
    }
  }

  @override
  Future<List<PurchaseDetails>> restorePurchases() async {
    try {
      logger.i('Restoring purchases...');

      await _iap.restorePurchases();

      // Restored purchases will come through purchaseUpdates stream
      // This is a simplified implementation - in practice, you'd wait for stream events
      return [];
    } catch (e, stackTrace) {
      logger.e('Error restoring purchases', e, stackTrace);
      return [];
    }
  }

  @override
  Stream<PurchaseUpdate> get purchaseUpdates => _purchaseUpdateController.stream;

  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          _purchaseUpdateController.add(PurchaseUpdate.pending());
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final details = _convertPurchaseDetails(purchaseDetails);
          _purchaseUpdateController.add(PurchaseUpdate.success(details));

          // Complete the purchase
          if (purchaseDetails.pendingCompletePurchase) {
            _iap.completePurchase(purchaseDetails);
          }
          break;

        case PurchaseStatus.error:
          _purchaseUpdateController.add(
            PurchaseUpdate.error(
              purchaseDetails.error?.message ?? 'Purchase failed',
            ),
          );
          if (purchaseDetails.pendingCompletePurchase) {
            _iap.completePurchase(purchaseDetails);
          }
          break;

        case PurchaseStatus.canceled:
          _purchaseUpdateController.add(
            const PurchaseUpdate(type: PurchaseUpdateType.cancelled),
          );
          break;
      }
    }
  }

  PurchaseDetails _convertPurchaseDetails(PurchaseDetails iapDetails) {
    String receiptData = '';
    String? originalTransactionId;

    if (Platform.isIOS) {
      final appStoreDetails = iapDetails as AppStorePurchaseDetails;
      receiptData = appStoreDetails.verificationData.serverVerificationData;
      originalTransactionId =
          appStoreDetails.verificationData.originalTransactionIdentifier;
    } else if (Platform.isAndroid) {
      final googleDetails = iapDetails as GooglePlayPurchaseDetails;
      receiptData = googleDetails.verificationData.serverVerificationData;
    }

    return PurchaseDetails(
      productId: iapDetails.productID,
      transactionId: iapDetails.purchaseID ?? '',
      originalTransactionId: originalTransactionId,
      transactionDate: iapDetails.transactionDate ?? DateTime.now(),
      receiptData: receiptData,
      platform: Platform.isIOS ? 'ios' : 'android',
    );
  }

  void dispose() {
    _purchaseSubscription?.cancel();
    _purchaseUpdateController.close();
  }
}
