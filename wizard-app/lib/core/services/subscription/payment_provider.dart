import 'package:appwizard/core/utils/app_logger.dart';

/// Abstract payment provider interface
/// Allows switching between IAP and Stripe implementations
abstract class PaymentProvider {
  final AppLogger logger;

  PaymentProvider(this.logger);

  /// Initialize the payment provider
  Future<bool> initialize();

  /// Load products from the store
  /// Returns store product details (price, currency, productId)
  Future<List<StoreProduct>> loadProducts(List<String> productIds);

  /// Purchase a product
  Future<PurchaseResult> purchaseProduct(String productId);

  /// Restore previous purchases
  Future<List<PurchaseDetails>> restorePurchases();

  /// Stream of purchase updates
  Stream<PurchaseUpdate> get purchaseUpdates;
}

/// Store product details (from App Store/Play Store)
class StoreProduct {
  final String productId;
  final String? price; // Formatted price (e.g., "$9.99")
  final String? currency; // Currency code (e.g., "USD")
  final String? description; // Store description
  final String? title; // Store title

  const StoreProduct({
    required this.productId,
    this.price,
    this.currency,
    this.description,
    this.title,
  });
}

/// Purchase result
class PurchaseResult {
  final bool success;
  final PurchaseDetails? purchaseDetails;
  final String? errorMessage;

  const PurchaseResult({
    required this.success,
    this.purchaseDetails,
    this.errorMessage,
  });

  factory PurchaseResult.success(PurchaseDetails details) {
    return PurchaseResult(
      success: true,
      purchaseDetails: details,
    );
  }

  factory PurchaseResult.failure(String error) {
    return PurchaseResult(
      success: false,
      errorMessage: error,
    );
  }
}

/// Purchase details (provider-agnostic)
class PurchaseDetails {
  final String productId;
  final String transactionId;
  final String? originalTransactionId; // iOS only
  final DateTime transactionDate;
  final String receiptData; // Base64 receipt (iOS) or purchase token (Android)
  final String platform; // 'ios' or 'android'

  const PurchaseDetails({
    required this.productId,
    required this.transactionId,
    this.originalTransactionId,
    required this.transactionDate,
    required this.receiptData,
    required this.platform,
  });
}

/// Purchase update event
class PurchaseUpdate {
  final PurchaseUpdateType type;
  final PurchaseDetails? purchaseDetails;
  final String? error;

  const PurchaseUpdate({
    required this.type,
    this.purchaseDetails,
    this.error,
  });

  factory PurchaseUpdate.pending() {
    return const PurchaseUpdate(type: PurchaseUpdateType.pending);
  }

  factory PurchaseUpdate.success(PurchaseDetails details) {
    return PurchaseUpdate(
      type: PurchaseUpdateType.success,
      purchaseDetails: details,
    );
  }

  factory PurchaseUpdate.error(String error) {
    return PurchaseUpdate(
      type: PurchaseUpdateType.error,
      error: error,
    );
  }
}

enum PurchaseUpdateType {
  pending,
  success,
  error,
  cancelled,
}
