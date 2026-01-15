import 'package:dartz/dartz.dart';
import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/domain/entities/subscription_product.dart';
import 'package:appwizard/domain/entities/subscription_status.dart';

/// Repository interface for subscription management
abstract class SubscriptionRepository {
  /// Get available subscription products
  /// Loads products from Remote Config and combines with store pricing
  Future<Either<Failure, List<SubscriptionProduct>>> getAvailableProducts();

  /// Purchase a subscription
  /// Sends receipt to backend for verification
  Future<Either<Failure, void>> purchaseSubscription(String productId);

  /// Get current subscription status
  /// Fetches from backend (populates in-memory cache on startup)
  Future<Either<Failure, SubscriptionStatus?>> getSubscriptionStatus();

  /// Restore previous purchases
  /// Restores purchases and syncs with backend
  Future<Either<Failure, void>> restorePurchases();
}
