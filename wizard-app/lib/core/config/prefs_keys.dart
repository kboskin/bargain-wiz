/// SharedPreferences keys shared across features.
class PrefsKeys {
  PrefsKeys._();

  /// Set to true after the first successful Express Dealmaker run; hides the home first-run nudge.
  static const String expressUsed = 'express_used';

  /// Set to true when onboarding finishes so Home can show the first-run nudge.
  static const String firstRunNudgePending = 'first_run_nudge_pending';

  /// Debug-only tier override (see FeatureGateService.debugTierKey).
  static const String debugTierOverride = 'debug_tier_override';

  /// Cached the `lines_that_land` Cloud Function payload (JSON). See LINES_THAT_LAND.md.
  static const String linesThatLandCache = 'lines_that_land_cache';

  /// ISO-8601 UTC timestamp of the last successful Lines that land fetch.
  static const String linesThatLandFetchedAt = 'lines_that_land_fetched_at';

  /// Last entitlement reported by the store (SubscriptionModel JSON); see the
  /// subscription repository. Cleared by Restore Purchases before re-reading the store.
  static const String subscriptionStatus = 'subscription_status';

  /// Random UUID minted on first launch; identifies this install to the profile endpoint
  /// while the user is signed out (see PROFILE_SYNC.md).
}
