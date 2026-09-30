import 'package:appwizard/core/services/profile_cache.dart';
import 'package:appwizard/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_status.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';
import 'package:appwizard/core/utils/app_logger.dart';

/// Service for checking subscription-based feature access
/// DI injectable service for feature gating throughout the app
class SubscriptionCheckerService {
  final SubscriptionRepository _repository;
  final AppLogger _logger;
  final ProfileCache _profile;

  SubscriptionCheckerService(
    this._repository,
    this._logger,
    this._profile,
  );

  /// The tier the person is entitled to: what they bought, else what an operator granted on
  /// their profile (still running), else free. A purchase always wins, so an override never
  /// hides a real plan and the plan reported to the profile stays the store's.
  Future<SubscriptionTier> getCurrentTier() async {
    final purchased = await _purchasedTier();
    if (purchased != SubscriptionTier.free) return purchased;
    final grant = _profile.subscriptionOverride;
    return grant != null && grant.grantsAt(DateTime.now()) ? grant.tier : SubscriptionTier.free;
  }

  /// Tier of the store purchase.
  /// Returns free if no active subscription
  Future<SubscriptionTier> _purchasedTier() async {
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

  /// Get current subscription status: the store purchase only, never the override.
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
