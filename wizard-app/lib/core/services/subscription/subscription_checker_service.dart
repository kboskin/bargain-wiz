import 'package:appwizard/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_status.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';
import 'package:appwizard/core/utils/app_logger.dart';

/// Service for checking subscription-based feature access
/// DI injectable service for feature gating throughout the app
class SubscriptionCheckerService {
  final SubscriptionRepository _repository;
  final AppLogger _logger;

  SubscriptionCheckerService(
    this._repository,
    this._logger,
  );

  /// Get current subscription tier
  /// Returns free if no active subscription
  Future<SubscriptionTier> getCurrentTier() async {
    try {
      final result = await _repository.getSubscriptionStatus();
      return result.fold(
        (failure) {
          _logger.w('Failed to get current tier');
          return SubscriptionTier.free;
        },
        (status) {
          if (status == null || !status.isActive || status.isExpired()) {
            return SubscriptionTier.free;
          }
          return status.tier;
        },
      );
    } catch (e, stackTrace) {
      _logger.e('Error getting current tier', e, stackTrace);
      return SubscriptionTier.free;
    }
  }

  /// Get current subscription status
  Future<SubscriptionStatus?> getCurrentStatus() async {
    try {
      final result = await _repository.getSubscriptionStatus();
      return result.fold(
        (failure) {
          _logger.w('Failed to get current status');
          return null;
        },
        (status) => status,
      );
    } catch (e, stackTrace) {
      _logger.e('Error getting current status', e, stackTrace);
      return null;
    }
  }
}
