import 'package:appwizard/core/services/subscription/payment_provider.dart';
import 'package:appwizard/core/utils/app_logger.dart';

/// Stripe Payment Provider placeholder
/// Ready for future Stripe integration
class StripePaymentProvider extends PaymentProvider {
  StripePaymentProvider(super.logger);

  @override
  Future<bool> initialize() async {
    logger.w('StripePaymentProvider not yet implemented');
    throw UnimplementedError('Stripe payment provider not yet implemented');
  }

  @override
  Future<List<StoreProduct>> loadProducts(List<String> productIds) async {
    throw UnimplementedError('Stripe payment provider not yet implemented');
  }

  @override
  Future<PurchaseResult> purchaseProduct(String productId) async {
    throw UnimplementedError('Stripe payment provider not yet implemented');
  }

  @override
  Future<List<PurchaseDetails>> restorePurchases() async {
    throw UnimplementedError('Stripe payment provider not yet implemented');
  }

  @override
  Stream<PurchaseUpdate> get purchaseUpdates =>
      throw UnimplementedError('Stripe payment provider not yet implemented');
}
