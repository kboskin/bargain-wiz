import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/features/paywall/data/models/paywall_config.dart';
import 'package:appwizard/features/paywall/domain/paywall_copy.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_status.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';

/// Copy for the Profile plan card and the drawer's plan name.
///
/// **No wording lives here.** Every string comes from `paywall_config.plan_card`, so changing
/// the offer — a different plan name, a longer trial, no trial at all — is a Remote Config
/// edit and never a release. This decides only *which* line applies:
///
/// | state | line |
/// |---|---|
/// | free | `free_subtitle` |
/// | paid, inside the trial window | `trial_subtitle` (`{n}` days), or `trial_ends_today_subtitle` on the last day |
/// | paid, the store reported a renewal date | `renews_subtitle` |
/// | paid, no date (restore or a QA override) | `active_subtitle` |
///
/// Placeholders filled: `{price}`, `{date}`, `{n}`. An unconfigured line renders as an empty
/// string, which the card hides, rather than as English describing an offer this build has
/// never seen. `{price}` resolves to nothing in the one case where no price is known (a debug
/// tier override against a config without `price_label`), leaving a shorter line.
class ProfilePlanCopy {
  ProfilePlanCopy._();

  /// Small caps line above the plan name ("CURRENT PLAN").
  static String label(
    PaywallPlanCardConfig? card, {
    PaywallTextResolver resolve = PaywallText.plain,
  }) =>
      resolve(card?.label).trim();

  /// Plan name for [tier]. Used by the Profile card and the drawer footer, so both always
  /// call the plan the same thing.
  static String planName(
    SubscriptionTier tier,
    PaywallPlanCardConfig? card, {
    PaywallTextResolver resolve = PaywallText.plain,
  }) {
    switch (tier) {
      case SubscriptionTier.premium:
        return resolve(card?.paidName).trim();
      case SubscriptionTier.free:
        return resolve(card?.freeName).trim();
    }
  }

  /// Plan card CTA: upgrade for free, manage for a subscriber.
  static String cta(
    SubscriptionTier tier,
    PaywallPlanCardConfig? card, {
    PaywallTextResolver resolve = PaywallText.plain,
  }) =>
      resolve(tier == SubscriptionTier.free ? card?.upgradeCta : card?.manageCta).trim();

  /// Whole days until [expiry] (rounded up, never negative).
  static int daysUntil(DateTime expiry, DateTime now) {
    final minutes = expiry.difference(now).inMinutes;
    if (minutes <= 0) return 0;
    return (minutes / (24 * 60)).ceil();
  }

  /// Subtitle under the plan name. See the class doc for which line applies when.
  static String planSub({
    required SubscriptionTier tier,
    required PaywallPlanCardConfig? card,
    SubscriptionStatus? status,
    String? price,
    required DateTime now,
    int trialDays = 0,
    String Function(DateTime date)? formatDate,
    PaywallTextResolver resolve = PaywallText.plain,
  }) {
    if (card == null) return '';
    final fmt = formatDate ?? ((d) => PaywallDates.monthDay(d));
    final expiry = status?.expiryDate;

    dynamic source;
    var days = 0;
    switch (tier) {
      case SubscriptionTier.free:
        source = card.freeSubtitle;
      case SubscriptionTier.premium:
        if (expiry == null) {
          source = card.activeSubtitle;
        } else {
          days = daysUntil(expiry, now);
          if (trialDays > 0 && days <= trialDays) {
            source = days == 0
                ? card.trialEndsTodaySubtitle
                : card.trialSubtitle?.sourceFor(days);
          } else {
            source = card.renewsSubtitle;
          }
        }
    }

    final template = resolve(source);
    if (template.trim().isEmpty) return '';
    return _tidy(TemplateText.fill(template, {
      'price': price?.trim() ?? '',
      'date': expiry == null ? '' : fmt(expiry),
      'n': '$days',
    }));
  }

  /// Collapses the gaps an absent `{price}` or `{date}` leaves behind.
  static String _tidy(String s) => s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
}
