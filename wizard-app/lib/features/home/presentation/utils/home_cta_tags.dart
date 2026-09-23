import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';

/// Which lock tags the Home CTA stack shows for a tier (see `FeatureGatePolicy`): both
/// Express Dealmaker and Pro Deal Closer carry a yellow 🔒 tag for free users.
class HomeCtaTags {
  const HomeCtaTags({required this.showExpressLockTag, required this.showProLockTag});

  final bool showExpressLockTag;
  final bool showProLockTag;

  /// Unknown tier (not resolved yet) is treated as free so the tags never flash off → on.
  static HomeCtaTags forTier(SubscriptionTier? tier) {
    final locked = (tier ?? SubscriptionTier.free) == SubscriptionTier.free;
    return HomeCtaTags(showExpressLockTag: locked, showProLockTag: locked);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeCtaTags &&
          other.showExpressLockTag == showExpressLockTag &&
          other.showProLockTag == showProLockTag;

  @override
  int get hashCode => Object.hash(showExpressLockTag, showProLockTag);
}


/// Whether the bobbing first-run nudge is visible.
///
/// Hidden forever once Express has been used; otherwise shown while onboarding
/// flagged it pending or the user has no saved deals yet.
bool showFirstRunNudge({
  required bool expressUsed,
  required bool nudgePending,
  required bool historyEmpty,
}) =>
    !expressUsed && (nudgePending || historyEmpty);
