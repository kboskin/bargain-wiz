/// Subscription tier enum - provider-agnostic.
///
/// One paid plan: `premium` unlocks everything, `free` is Lines that land, History and Profile.
/// The plan is sold in several billing periods (monthly, weekly); those are products in
/// `subscription_config`, not tiers.
enum SubscriptionTier {
  free,
  premium;

  static SubscriptionTier fromName(String? name) =>
      values.where((t) => t.name == name).firstOrNull ?? SubscriptionTier.free;
}
