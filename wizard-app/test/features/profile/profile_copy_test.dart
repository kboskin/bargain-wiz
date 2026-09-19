import 'package:flutter_test/flutter_test.dart';

import 'package:appwizard/features/profile/domain/profile_identity.dart';
import 'package:appwizard/features/profile/domain/profile_plan_copy.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_status.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';

String _fmt(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}';
}

void main() {
  final now = DateTime(2025, 9, 11, 10);

  group('ProfilePlanCopy.planName', () {
    test('uses the paywall option title when present', () {
      expect(ProfilePlanCopy.planName(SubscriptionTier.premium, optionTitle: 'Mago Visión'), 'Mago Visión');
    });

    test('falls back to constants per tier', () {
      expect(ProfilePlanCopy.planName(SubscriptionTier.premium), 'Vision Wizard');
      expect(ProfilePlanCopy.planName(SubscriptionTier.basic, optionTitle: '  '), 'Text Wizard');
      expect(ProfilePlanCopy.planName(SubscriptionTier.free), 'Free plan');
    });
  });

  group('ProfilePlanCopy.planSub', () {
    test('free plan', () {
      expect(
        ProfilePlanCopy.planSub(tier: SubscriptionTier.free, now: now),
        'Lines that land only · upgrade to negotiate',
      );
    });

    test('premium inside the trial window counts days and shows the price', () {
      final status = SubscriptionStatus(
        tier: SubscriptionTier.premium,
        isActive: true,
        expiryDate: now.add(const Duration(days: 1, hours: 6)),
      );
      expect(
        ProfilePlanCopy.planSub(
          tier: SubscriptionTier.premium,
          status: status,
          price: r'$7.99/wk',
          now: now,
          formatDate: _fmt,
        ),
        r'Trial ends in 2 days · then $7.99/wk',
      );
    });

    test('premium past the trial window renews on the expiry date', () {
      final status = SubscriptionStatus(
        tier: SubscriptionTier.premium,
        isActive: true,
        expiryDate: DateTime(2025, 10, 1),
      );
      expect(
        ProfilePlanCopy.planSub(
          tier: SubscriptionTier.premium,
          status: status,
          price: r'$7.99/wk',
          now: now,
          formatDate: _fmt,
        ),
        r'Renews Oct 1 · $7.99/wk',
      );
    });

    test('basic shows price then renewal date', () {
      final status = SubscriptionStatus(
        tier: SubscriptionTier.basic,
        isActive: true,
        expiryDate: DateTime(2025, 9, 18),
      );
      expect(
        ProfilePlanCopy.planSub(
          tier: SubscriptionTier.basic,
          status: status,
          price: r'$4.99/wk',
          now: now,
          formatDate: _fmt,
        ),
        r'$4.99/wk · renews Sep 18',
      );
    });

    test('paid tiers without status or price still read sensibly (debug override)', () {
      expect(
        ProfilePlanCopy.planSub(tier: SubscriptionTier.premium, now: now),
        'Everything unlocked',
      );
      expect(
        ProfilePlanCopy.planSub(tier: SubscriptionTier.basic, now: now, price: r'$4.99/wk'),
        r'$4.99/wk · cancel anytime',
      );
    });

    test('daysUntil rounds up and never goes negative', () {
      expect(ProfilePlanCopy.daysUntil(now.add(const Duration(hours: 1)), now), 1);
      expect(ProfilePlanCopy.daysUntil(now.add(const Duration(days: 2)), now), 2);
      expect(ProfilePlanCopy.daysUntil(now.subtract(const Duration(days: 1)), now), 0);
    });

    test('cta is Upgrade for free and Manage otherwise', () {
      expect(ProfilePlanCopy.cta(SubscriptionTier.free), 'Upgrade');
      expect(ProfilePlanCopy.cta(SubscriptionTier.basic), 'Manage');
      expect(ProfilePlanCopy.cta(SubscriptionTier.premium), 'Manage');
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
