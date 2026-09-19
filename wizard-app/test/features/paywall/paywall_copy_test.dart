import 'package:flutter_test/flutter_test.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/features/paywall/data/models/paywall_config.dart';
import 'package:appwizard/features/paywall/domain/paywall_args.dart';
import 'package:appwizard/features/paywall/domain/paywall_copy.dart';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_product.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';

PaywallConfig _config({
  List<Map<String, dynamic>>? trialTimeline,
  Map<String, dynamic> extra = const {},
}) =>
    PaywallConfig.fromJson({
      'type': 'test',
      'title': {'en': 'Unlock Bargain Wiz'},
      'description': {'en': 'Choose your negotiation power.'},
      'options': [
        {
          'id': 'text',
          'tier': 'basic',
          'title': {'en': 'Text Wizard'},
          'description': {'en': 'Perfect for chat-based bargaining.'},
          'price_label': r'$4.99/wk',
        },
        {
          'id': 'vision',
          'tier': 'premium',
          'title': {'en': 'Vision Wizard'},
          'description': {'en': 'Uses screenshots to find leverage.'},
          'badge': {'en': 'Recommended'},
          'price_label': r'$7.99/wk',
        },
      ],
      'metadata': {
        'default_selected_option_id': 'vision',
        'layout': 'cards',
        'option_visuals': <String, String>{},
      },
      'next_button_text': {'en': 'Try for free'},
      'note_text': {'en': 'Free trial, then {price}. Cancel anytime.'},
      'trial_days': 3,
      if (trialTimeline != null) 'trial_timeline': trialTimeline,
      'context_hints': {
        'free': {'en': 'Your first 3 days are on us.'},
        'basic_express': {'en': 'Screenshots need Vision Wizard.'},
      },
      ...extra,
    });

const _remoteTimeline = [
  {
    'day': 0,
    'title': {'en': 'Today · {date}'},
    'subtitle': {'en': 'Unlock every feature of {plan}'},
  },
  {
    'day': 2,
    'title': {'en': 'Day 2 · {date}'},
    'subtitle': {'en': 'We remind you before the trial ends'},
  },
  {
    'day': 3,
    'title': {'en': 'Day 3 · {date}'},
    'subtitle': {'en': 'Billing starts at {price} unless cancelled'},
  },
];

SubscriptionProduct _product(SubscriptionTier tier, {String? price, String? id}) =>
    SubscriptionProduct(
      productId: id ?? 'store.${tier.name}',
      tier: tier,
      title: tier.name,
      description: '',
      price: price,
      currency: price == null ? null : 'USD',
      features: const [],
      displayOrder: 0,
    );

void main() {
  group('PaywallTimelineBuilder', () {
    final now = DateTime(2025, 9, 11, 15, 42);

    test('fills {date}, {plan} and {price} from trial_timeline', () {
      final rows = PaywallTimelineBuilder.build(
        config: _config(trialTimeline: _remoteTimeline),
        now: now,
        plan: 'Vision Wizard',
        price: r'$7.99/wk',
        locale: 'en',
      );

      expect(rows, hasLength(3));
      expect(rows[0].title, 'Today · Sep 11');
      expect(rows[0].subtitle, 'Unlock every feature of Vision Wizard');
      expect(rows[1].title, 'Day 2 · Sep 13');
      expect(rows[1].subtitle, 'We remind you before the trial ends');
      expect(rows[2].title, 'Day 3 · Sep 14');
      expect(rows[2].subtitle, r'Billing starts at $7.99/wk unless cancelled');
    });

    test('assigns ink / purple / amber dots in order', () {
      final rows = PaywallTimelineBuilder.build(
        config: _config(trialTimeline: _remoteTimeline),
        now: now,
        plan: 'Vision Wizard',
        price: r'$7.99/wk',
        locale: 'en',
      );
      expect(rows.map((r) => r.dotColor), [WizColors.ink, WizColors.purple, WizColors.amber]);
    });

    test('rolls dates over month boundaries', () {
      final rows = PaywallTimelineBuilder.build(
        config: _config(trialTimeline: _remoteTimeline),
        now: DateTime(2025, 9, 30),
        plan: 'Vision Wizard',
        price: r'$7.99/wk',
        locale: 'en',
      );
      expect(rows[1].title, 'Day 2 · Oct 2');
      expect(rows[2].title, 'Day 3 · Oct 3');
    });

    test('falls back to three default rows from trial_days when the list is empty', () {
      final rows = PaywallTimelineBuilder.build(
        config: _config(),
        now: now,
        plan: 'Text Wizard',
        price: r'$4.99/wk',
        locale: 'en',
      );
      expect(rows.map((r) => r.day), [0, 2, 3]);
      expect(rows[0].title, 'Today · Sep 11');
      expect(rows[0].subtitle, 'Unlock every feature of Text Wizard');
      expect(rows[1].title, 'Day 2 · Sep 13');
      expect(rows[2].title, 'Day 3 · Sep 14');
      expect(rows[2].subtitle, r'Billing starts at $4.99/wk unless cancelled');
    });

    test('prefers legacy timeline_* fields over the hardcoded defaults', () {
      final rows = PaywallTimelineBuilder.build(
        config: _config(extra: {
          'trial_days': 7,
          'timeline_today_text': {'en': 'Start · {date}'},
          'timeline_billing_subtitle': {'en': 'You pay {price} on {date}'},
        }),
        now: now,
        plan: 'Vision Wizard',
        price: r'$7.99/wk',
        locale: 'en',
      );
      expect(rows.map((r) => r.day), [0, 6, 7]);
      expect(rows[0].title, 'Start · Sep 11');
      expect(rows[1].title, 'Day 6 · Sep 17');
      expect(rows[2].subtitle, r'You pay $7.99/wk on Sep 18');
    });

    test('tidies the copy when no price is available', () {
      final rows = PaywallTimelineBuilder.build(
        config: _config(trialTimeline: _remoteTimeline),
        now: now,
        plan: 'Vision Wizard',
        price: null,
        locale: 'en',
      );
      expect(rows[2].subtitle, 'Billing starts at unless cancelled');
    });

    test('uses a custom date formatter when provided', () {
      final rows = PaywallTimelineBuilder.build(
        config: _config(trialTimeline: _remoteTimeline),
        now: now,
        plan: 'Vision Wizard',
        price: r'$7.99/wk',
        formatDate: (d) => '${d.day}/${d.month}',
      );
      expect(rows[2].title, 'Day 3 · 14/9');
    });
  });

  group('PaywallDates', () {
    test('formats as "Sep 11" in English', () {
      expect(PaywallDates.monthDay(DateTime(2025, 9, 11), locale: 'en'), 'Sep 11');
    });

    test('falls back to English for locales without loaded data', () {
      expect(PaywallDates.monthDay(DateTime(2025, 9, 11), locale: 'xx-YY'), 'Sep 11');
    });
  });

  group('PaywallHints', () {
    final hints = _config().contextHints;

    test('free entries pick the "free" hint', () {
      expect(PaywallHints.hintFor(hints, PaywallEntry.expressFree)?.toJson(),
          {'en': 'Your first 3 days are on us.'});
      expect(PaywallHints.hintFor(hints, PaywallEntry.proFree)?.toJson(),
          {'en': 'Your first 3 days are on us.'});
    });

    test('basic → Express picks the "basic_express" hint', () {
      expect(PaywallHints.hintFor(hints, PaywallEntry.expressBasic)?.toJson(),
          {'en': 'Screenshots need Vision Wizard.'});
    });

    test('profile / onboarding / other show no hint', () {
      expect(PaywallHints.hintFor(hints, PaywallEntry.profile), isNull);
      expect(PaywallHints.hintFor(hints, PaywallEntry.onboarding), isNull);
      expect(PaywallHints.hintFor(hints, PaywallEntry.other), isNull);
    });

    test('missing key in config yields null', () {
      expect(PaywallHints.hintFor(const <String, MultilocaleText>{}, PaywallEntry.expressFree), isNull);
    });
  });

  group('PaywallPricing.priceFor', () {
    final config = _config();
    final vision = config.options.firstWhere((o) => o.id == 'vision');
    final text = config.options.firstWhere((o) => o.id == 'text');

    test('prefers the store price for the matching tier', () {
      final products = [
        _product(SubscriptionTier.basic, price: r'$4.49'),
        _product(SubscriptionTier.premium, price: r'$8.49'),
      ];
      expect(PaywallPricing.priceFor(vision, products), r'$8.49');
      expect(PaywallPricing.priceFor(text, products), r'$4.49');
    });

    test('falls back to price_label when the tier has no product', () {
      final products = [_product(SubscriptionTier.basic, price: r'$4.49')];
      expect(PaywallPricing.priceFor(vision, products), r'$7.99/wk');
    });

    test('falls back to price_label when the store price is empty', () {
      final products = [_product(SubscriptionTier.premium, price: '  ')];
      expect(PaywallPricing.priceFor(vision, products), r'$7.99/wk');
    });

    test('returns null when neither a store price nor a label exists', () {
      final bare = PaywallOption(
        id: 'vision',
        tier: 'premium',
        title: const MultilocaleText('Vision Wizard'),
        description: const MultilocaleText(''),
      );
      expect(PaywallPricing.priceFor(bare, const []), isNull);
    });

    test('resolves a multilocale price_label through the resolver', () {
      final option = PaywallOption(
        id: 'vision',
        tier: 'premium',
        title: const MultilocaleText('Vision Wizard'),
        description: const MultilocaleText(''),
        priceLabel: const MultilocaleText({'en': r'$7.99/wk', 'es': r'7,99 $/sem'}),
      );
      expect(PaywallPricing.priceFor(option, const []), r'$7.99/wk');
      expect(
        PaywallPricing.priceFor(option, const [], resolve: (v) => (v as MultilocaleText).toJson()['es']),
        r'7,99 $/sem',
      );
    });
  });

  group('PaywallPricing.productIdFor', () {
    final vision = _config().options.firstWhere((o) => o.id == 'vision');

    test('uses the store product id when loaded', () {
      expect(
        PaywallPricing.productIdFor(vision, [_product(SubscriptionTier.premium, id: 'store.vision')]),
        'store.vision',
      );
    });

    test('falls back to the tier constant when the store has nothing', () {
      expect(PaywallPricing.productIdFor(vision, const []), 'com.bargain.wiz.premium');
    });
  });

  group('PaywallStepConfig.asksNotificationPermission', () {
    test('is true for button_action: request_permission', () {
      final step = PaywallStepConfig.fromJson({
        'id': 'trial_reminder',
        'button_action': 'request_permission',
      });
      expect(step.asksNotificationPermission, isTrue);
    });

    test('falls back to the reminder id when no action is configured', () {
      expect(PaywallStepConfig.fromJson({'id': 'reminder'}).asksNotificationPermission, isTrue);
      expect(PaywallStepConfig.fromJson({'id': 'intro'}).asksNotificationPermission, isFalse);
    });

    test('an explicit non-permission action wins over the id', () {
      final step = PaywallStepConfig.fromJson({'id': 'reminder', 'button_action': 'continue'});
      expect(step.asksNotificationPermission, isFalse);
    });

    test('the bundled reminder step asks for the permission', () {
      final steps = _config(extra: {
        'steps': [
          {'id': 'intro', 'button_text': {'en': r'Try for $0.00'}},
          {
            'id': 'reminder',
            'button_text': {'en': 'Continue for FREE'},
            'button_action': 'request_permission',
          },
        ],
      }).steps;
      expect(steps.map((s) => s.asksNotificationPermission), [false, true]);
    });
  });
}
