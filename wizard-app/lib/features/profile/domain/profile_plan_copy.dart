import 'package:appwizard/features/paywall/domain/paywall_copy.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_status.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';

/// Copy for the Profile plan card (design handoff §8), derived from tier + subscription status.
class ProfilePlanCopy {
  ProfilePlanCopy._();

  static const String freeName = 'Free plan';
  static const String premiumName = 'Premium';
  static const String freeSub = 'Lines that land only · upgrade to negotiate';

  /// Plan title. The billing period is not part of the name; it shows through the price
  /// ("$19.99/mo") in [planSub].
  static String planName(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.premium:
        return premiumName;
      case SubscriptionTier.free:
        return freeName;
    }
  }

  static String cta(SubscriptionTier tier) => tier == SubscriptionTier.free ? 'Upgrade' : 'Manage';

  /// Whole days until [expiry] (rounded up, never negative).
  static int daysUntil(DateTime expiry, DateTime now) {
    final minutes = expiry.difference(now).inMinutes;
    if (minutes <= 0) return 0;
    return (minutes / (24 * 60)).ceil();
  }

  /// Subtitle under the plan name.
  ///
  /// premium: "Renews {date} · {price}" when the store reports an expiry, else
  ///          "{price} · cancel anytime". With a trial configured ([trialDays] > 0) and the
  ///          expiry inside it: "Trial ends in {n} days · then {price}".
  /// free:    "Lines that land only · upgrade to negotiate".
  static String planSub({
    required SubscriptionTier tier,
    SubscriptionStatus? status,
    String? price,
    required DateTime now,
    int trialDays = 0,
    String Function(DateTime date)? formatDate,
  }) {
    final fmt = formatDate ?? ((d) => PaywallDates.monthDay(d));
    final expiry = status?.expiryDate;
    final hasPrice = price != null && price.trim().isNotEmpty;

    switch (tier) {
      case SubscriptionTier.free:
        return freeSub;
      case SubscriptionTier.premium:
        if (expiry != null) {
          final days = daysUntil(expiry, now);
          if (trialDays > 0 && days <= trialDays) {
            final when = days == 0
                ? 'Trial ends today'
                : 'Trial ends in $days ${days == 1 ? 'day' : 'days'}';
            return hasPrice ? '$when · then $price' : when;
          }
          return hasPrice ? 'Renews ${fmt(expiry)} · $price' : 'Renews ${fmt(expiry)}';
        }
        return hasPrice ? '$price · cancel anytime' : 'Everything unlocked';
    }
  }
}
