import 'package:flutter_test/flutter_test.dart';

import 'package:appwizard/features/profile/domain/profile_identity.dart';
import 'package:appwizard/features/profile/domain/profile_options.dart';
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

  group('ProfileOptions.parse', () {
    const screens = [
      {
        'type': 'select',
        'answer_structure': {'answer_key_name': 'negotiation_vibe'},
        'options': [
          {'label': 'Friendly Collaborator', 'value': 'friendly'},
        ],
      },
      {
        'type': 'select_group',
        'groups': [
          {
            'answer_key_name': 'favorite_marketplace',
            'options': [
              {
                'label': 'eBay',
                'value': 'ebay',
                'icon': {'code': '0xf4f4', 'font': 'brands'},
              },
              {
                'label': {'en': 'Other', 'es': 'Otro'},
                'value': 'other',
              },
            ],
          },
          {
            'answer_key_name': 'deals_per_month',
            'options': [
              {'label': '0–2', 'value': '0_2'},
            ],
          },
        ],
      },
    ];

    test('reads group options for marketplace and deals per month', () {
      final markets = ProfileOptions.parse(screens, 'favorite_marketplace')!;
      expect(markets.map((o) => o.value), ['ebay', 'other']);
      expect(markets.last.label, {'en': 'Other', 'es': 'Otro'});
      expect(markets.first.iconRaw, {'code': '0xf4f4', 'font': 'brands'});
      expect(markets.last.iconRaw, isNull);
      expect(ProfileOptions.parse(screens, 'deals_per_month')!.single.value, '0_2');
    });

    test('reads top-level select options', () {
      expect(ProfileOptions.parse(screens, 'negotiation_vibe')!.single.value, 'friendly');
    });

    test('returns null for unknown keys or malformed input', () {
      expect(ProfileOptions.parse(screens, 'missing'), isNull);
      expect(ProfileOptions.parse('nope', 'favorite_marketplace'), isNull);
    });

    test('labelFor resolves labels and falls back to the raw value', () {
      String resolve(dynamic v) => v is Map ? v['en'].toString() : v.toString();
      expect(
        ProfileOptions.labelFor(ProfileOptions.marketplaceFallback, 'facebook', resolve, fallback: '—'),
        'Facebook Marketplace',
      );
      expect(
        ProfileOptions.labelFor(ProfileOptions.marketplaceFallback, 'other', resolve, fallback: '—'),
        'Other',
      );
      expect(ProfileOptions.labelFor(ProfileOptions.marketplaceFallback, null, resolve, fallback: '—'), '—');
      expect(ProfileOptions.labelFor(ProfileOptions.marketplaceFallback, 'zzz', resolve, fallback: '—'), 'zzz');
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
