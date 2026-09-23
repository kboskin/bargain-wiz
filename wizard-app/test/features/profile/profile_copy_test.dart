import 'package:flutter_test/flutter_test.dart';

import 'package:appwizard/features/paywall/data/models/paywall_config.dart';
import 'package:appwizard/features/profile/domain/profile_identity.dart';
import 'package:appwizard/features/profile/domain/profile_plan_copy.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_status.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';

String _fmt(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}';
}

/// The wording is the template's, so the tests configure it the way the app does.
PaywallPlanCardConfig _card([Map<String, dynamic> overrides = const {}]) =>
    PaywallPlanCardConfig.fromJson({
      'label': {'en': 'CURRENT PLAN'},
      'free_name': {'en': 'Free plan'},
      'paid_name': {'en': 'Premium'},
      'free_subtitle': {'en': 'Lines that land only · upgrade to negotiate'},
      'trial_subtitle': {
        'one': {'en': 'Trial ends in {n} day · then {price}'},
        'other': {'en': 'Trial ends in {n} days · then {price}'},
      },
      'trial_ends_today_subtitle': {'en': 'Trial ends today · then {price}'},
      'renews_subtitle': {'en': 'Renews {date} · {price}'},
      'active_subtitle': {'en': '{price} · cancel anytime'},
      'upgrade_cta': {'en': 'Upgrade'},
      'manage_cta': {'en': 'Manage'},
      ...overrides,
    });

void main() {
  final now = DateTime(2025, 9, 11, 10);
  final card = _card();

  String sub({
    required SubscriptionTier tier,
    SubscriptionStatus? status,
    String? price,
    int trialDays = 0,
  }) =>
      ProfilePlanCopy.planSub(
        tier: tier,
        card: card,
        status: status,
        price: price,
        now: now,
        trialDays: trialDays,
        formatDate: _fmt,
      );

  SubscriptionStatus _paid(DateTime expiry) => SubscriptionStatus(
        tier: SubscriptionTier.premium,
        isActive: true,
        expiryDate: expiry,
      );

  group('names and CTAs come from the template', () {
    test('plan name per tier', () {
      expect(ProfilePlanCopy.planName(SubscriptionTier.premium, card), 'Premium');
      expect(ProfilePlanCopy.planName(SubscriptionTier.free, card), 'Free plan');
    });

    test('cta is upgrade for free and manage for a subscriber', () {
      expect(ProfilePlanCopy.cta(SubscriptionTier.free, card), 'Upgrade');
      expect(ProfilePlanCopy.cta(SubscriptionTier.premium, card), 'Manage');
    });

    test('label rides along', () {
      expect(ProfilePlanCopy.label(card), 'CURRENT PLAN');
    });

    test('nothing is invented when the template says nothing', () {
      expect(ProfilePlanCopy.planName(SubscriptionTier.premium, null), '');
      expect(ProfilePlanCopy.planName(SubscriptionTier.free, null), '');
      expect(ProfilePlanCopy.cta(SubscriptionTier.premium, null), '');
      expect(ProfilePlanCopy.label(null), '');
      // No plan_card at all, and a plan_card missing the line this state needs.
      expect(
        ProfilePlanCopy.planSub(
          tier: SubscriptionTier.premium,
          card: null,
          price: r'$19.99/mo',
          now: now,
        ),
        '',
      );
      expect(
        ProfilePlanCopy.planSub(
          tier: SubscriptionTier.free,
          card: PaywallPlanCardConfig.fromJson(const {'paid_name': {'en': 'Premium'}}),
          now: now,
        ),
        '',
      );
    });
  });

  group('ProfilePlanCopy.planSub', () {
    test('free plan', () {
      expect(
        sub(tier: SubscriptionTier.free),
        'Lines that land only · upgrade to negotiate',
      );
    });

    test('inside the trial window it counts the days and pluralises', () {
      expect(
        sub(
          tier: SubscriptionTier.premium,
          status: _paid(now.add(const Duration(days: 1, hours: 6))),
          price: r'$6.99/wk',
          trialDays: 2,
        ),
        r'Trial ends in 2 days · then $6.99/wk',
      );
      expect(
        sub(
          tier: SubscriptionTier.premium,
          status: _paid(now.add(const Duration(hours: 6))),
          price: r'$6.99/wk',
          trialDays: 2,
        ),
        r'Trial ends in 1 day · then $6.99/wk',
      );
    });

    test('on the last day it says so instead of counting zero', () {
      expect(
        sub(
          tier: SubscriptionTier.premium,
          status: _paid(now.subtract(const Duration(minutes: 1))),
          price: r'$6.99/wk',
          trialDays: 2,
        ),
        r'Trial ends today · then $6.99/wk',
      );
    });

    test('past the trial window it renews on the expiry date', () {
      expect(
        sub(
          tier: SubscriptionTier.premium,
          status: _paid(DateTime(2025, 10, 1)),
          price: r'$19.99/mo',
          trialDays: 2,
        ),
        r'Renews Oct 1 · $19.99/mo',
      );
    });

    test('an offer with no trial never shows trial copy', () {
      expect(
        sub(
          tier: SubscriptionTier.premium,
          status: _paid(now.add(const Duration(days: 1, hours: 6))),
          price: r'$6.99/wk',
        ),
        r'Renews Sep 12 · $6.99/wk',
      );
    });

    test('paid without a date (restore or a QA override) falls to the active line', () {
      expect(
        sub(tier: SubscriptionTier.premium, price: r'$19.99/mo'),
        r'$19.99/mo · cancel anytime',
      );
    });

    test('a missing price leaves a shorter line, not a gap or a brace', () {
      final line = sub(tier: SubscriptionTier.premium);
      expect(line, '· cancel anytime');
      expect(line, isNot(contains('{price}')));
      expect(line, isNot(contains('  ')));
    });

    test('daysUntil rounds up and never goes negative', () {
      expect(ProfilePlanCopy.daysUntil(now.add(const Duration(hours: 1)), now), 1);
      expect(ProfilePlanCopy.daysUntil(now.add(const Duration(days: 2)), now), 2);
      expect(ProfilePlanCopy.daysUntil(now.subtract(const Duration(days: 1)), now), 0);
    });
  });

  group('ProfileIdentity', () {
    test('guest copy', () {
      expect(ProfileIdentity.guest.name, 'Guest wizard');
      expect(ProfileIdentity.guest.initial, '?');
      expect(ProfileIdentity.guest.subtitle, 'Sign in to sync deals across devices');
      expect(ProfileIdentity.guest.signedIn, isFalse);
    });

    test('display name wins, subtitle is email · provider', () {
      final id = ProfileIdentity.signedInUser(
        displayName: 'dana',
        email: 'dana@example.com',
        providerId: 'google.com',
      );
      expect(id.name, 'dana');
      expect(id.initial, 'D');
      expect(id.subtitle, 'dana@example.com · Google');
      expect(id.signedIn, isTrue);
    });

    test('falls back to the email local part and maps Apple / password providers', () {
      final apple = ProfileIdentity.signedInUser(email: 'sam.lee@icloud.com', providerId: 'apple.com');
      expect(apple.name, 'sam.lee');
      expect(apple.initial, 'S');
      expect(apple.subtitle, 'sam.lee@icloud.com · Apple');
      expect(ProfileIdentity.providerLabel('password'), 'Email');
      expect(ProfileIdentity.providerLabel(null), '');
    });
  });
}
