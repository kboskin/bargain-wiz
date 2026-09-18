import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';

/// Which lock tags the Home CTA stack shows for a tier (see README §3 / `FeatureGatePolicy`).
///
/// - Express Dealmaker: yellow "Vision" tag for free and basic (Text Wizard).
/// - Pro Deal Closer: yellow 🔒 tag for free only.
class HomeCtaTags {
  const HomeCtaTags({required this.showExpressVisionTag, required this.showProLockTag});

  final bool showExpressVisionTag;
  final bool showProLockTag;

  /// Unknown tier (not resolved yet) is treated as free so the tags never flash off → on.
  static HomeCtaTags forTier(SubscriptionTier? tier) {
    final t = tier ?? SubscriptionTier.free;
    return HomeCtaTags(
      showExpressVisionTag: t != SubscriptionTier.premium,
      showProLockTag: t == SubscriptionTier.free,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeCtaTags &&
          other.showExpressVisionTag == showExpressVisionTag &&
          other.showProLockTag == showProLockTag;

  @override
  int get hashCode => Object.hash(showExpressVisionTag, showProLockTag);
}

/// Plan name shown in the drawer footer ("v2.0 · {tier}").
String tierLabel(SubscriptionTier? tier) {
  switch (tier ?? SubscriptionTier.free) {
    case SubscriptionTier.free:
      return 'Free plan';
    case SubscriptionTier.basic:
      return 'Text Wizard';
    case SubscriptionTier.premium:
      return 'Vision Wizard';
  }
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
