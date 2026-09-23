import 'package:flutter_test/flutter_test.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/features/paywall/data/models/paywall_config.dart';
import 'package:appwizard/features/paywall/domain/paywall_args.dart';
import 'package:appwizard/features/paywall/domain/paywall_copy.dart';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_product.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';

/// The timeline wording every derived-row test shares. Lives in the config, like the app's.
const _timelineWording = {
  'timeline_today_text': {'en': 'Today · {date}'},
  'timeline_today_subtitle': {'en': 'Unlock every feature of {plan}'},
  'timeline_reminder_text': {'en': 'Day {day} · {date}'},
  'timeline_reminder_subtitle': {'en': 'We remind you before the trial ends'},
  'timeline_billing_text': {'en': 'Day {day} · {date}'},
  'timeline_billing_subtitle': {'en': 'Billing starts at {price} unless cancelled'},
};

/// The bundled offer: one premium plan, monthly (preselected) and weekly, 2 days free.
PaywallConfig _config({
  int trialDays = 2,
  List<Map<String, dynamic>>? trialTimeline,
  Map<String, dynamic> extra = const {},
}) =>
    PaywallConfig.fromJson({
      'type': 'test',
      'title': {'en': 'Unlock Bargain Wiz'},
      'description': {'en': 'One plan. Every wizard power.'},
      'options': [
        {
          'id': 'monthly',
          'tier': 'premium',
          'title': {'en': 'Monthly'},
          'description': {'en': 'One saved deal covers the month.'},
          'badge': {'en': 'Best value'},
          'price_label': {'en': r'$19.99/mo'},
          'price_suffix': {'en': '/mo'},
        },
        {
          'id': 'weekly',
          'tier': 'premium',
          'title': {'en': 'Weekly'},
          'description': {'en': 'Negotiating this week? One deal covers it.'},
          'price_label': {'en': r'$6.99/wk'},
          'price_suffix': {'en': '/wk'},
        },
      ],
      'metadata': {
        'default_selected_option_id': 'monthly',
        'layout': 'cards',
        'option_visuals': <String, String>{},
      },
      'next_button_text': {'en': 'Unlock Bargain Wiz'},
      'note_text': {'en': '{price}, renews automatically. Cancel anytime.'},
      'trial_days': trialDays,
      ..._timelineWording,
      if (trialTimeline != null) 'trial_timeline': trialTimeline,
      'context_hints': {
        'free': {'en': 'Express and Pro need the full wizard.'},
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

SubscriptionProduct _product({String? key, String? price, String? id}) => SubscriptionProduct(
      productId: id ?? 'store.${key ?? 'premium'}',
      key: key,
      tier: SubscriptionTier.premium,
      title: key ?? 'premium',
      description: '',
      price: price,
      currency: price == null ? null : 'USD',
      features: const [],
      displayOrder: 0,
    );

void main() {
  group('PaywallTimelineBuilder', () {
    final now = DateTime(2025, 9, 11, 15, 42);

    test('shows nothing when there is no trial and no rows are configured', () {
      final rows = PaywallTimelineBuilder.build(
        config: _config(trialDays: 0),
        now: now,
        plan: 'Premium',
        price: r'$19.99/mo',
        locale: 'en',
      );
      expect(rows, isEmpty);
    });

    test('shows nothing when the wording is not configured, rather than English defaults', () {
      final bare = PaywallConfig.fromJson({
        'type': 'test',
        'title': {'en': 'Unlock Bargain Wiz'},
        'description': {'en': ''},
        'options': const <Map<String, dynamic>>[],
        'metadata': {
          'default_selected_option_id': 'monthly',
          'layout': 'cards',
          'option_visuals': <String, String>{},
        },
        'next_button_text': {'en': ''},
        'note_text': {'en': ''},
        'trial_days': 2,
      });
      expect(
        PaywallTimelineBuilder.build(config: bare, now: now, plan: 'Premium', price: r'$6.99/wk'),
        isEmpty,
      );
    });

    test('fills {date}, {plan} and {price} from trial_timeline', () {
      final rows = PaywallTimelineBuilder.build(
        config: _config(trialTimeline: _remoteTimeline),
        now: now,
        plan: 'Premium',
        price: r'$6.99/wk',
        locale: 'en',
      );

      expect(rows, hasLength(3));
      expect(rows[0].title, 'Today · Sep 11, 2025');
      expect(rows[0].subtitle, 'Unlock every feature of Premium');
      expect(rows[1].title, 'Day 2 · Sep 13, 2025');
      expect(rows[1].subtitle, 'We remind you before the trial ends');
      expect(rows[2].title, 'Day 3 · Sep 14, 2025');
      expect(rows[2].subtitle, r'Billing starts at $6.99/wk unless cancelled');
    });

    test('assigns ink / purple / amber dots in order', () {
      final rows = PaywallTimelineBuilder.build(
        config: _config(trialTimeline: _remoteTimeline),
        now: now,
        plan: 'Premium',
        price: r'$6.99/wk',
        locale: 'en',
      );
      expect(rows.map((r) => r.dotColor), [WizColors.ink, WizColors.purple, WizColors.amber]);
    });

    test('rolls dates over month boundaries', () {
      final rows = PaywallTimelineBuilder.build(
        config: _config(trialTimeline: _remoteTimeline),
        now: DateTime(2025, 9, 30),
        plan: 'Premium',
        price: r'$6.99/wk',
        locale: 'en',
      );
      expect(rows[1].title, 'Day 2 · Oct 2, 2025');
      expect(rows[2].title, 'Day 3 · Oct 3, 2025');
    });

    test('derives the rows from trial_days: today, the reminder, the billing day', () {
      final rows = PaywallTimelineBuilder.build(
        config: _config(),
        now: now,
        plan: 'Premium',
        price: r'$6.99/wk',
        locale: 'en',
      );
      expect(rows.map((r) => r.day), [0, 1, 2]);
      expect(rows[0].title, 'Today · Sep 11, 2025');
      expect(rows[0].subtitle, 'Unlock every feature of Premium');
      expect(rows[1].title, 'Day 1 · Sep 12, 2025');
      expect(rows[2].title, 'Day 2 · Sep 13, 2025');
      expect(rows[2].subtitle, r'Billing starts at $6.99/wk unless cancelled');
    });

    test('a row title that counts days takes its singular form', () {
      final rows = PaywallTimelineBuilder.build(
        config: _config(trialDays: 2, extra: {
          'timeline_reminder_text': {
            'one': {'en': 'In {day} Day – Reminder'},
            'other': {'en': 'In {day} Days – Reminder'},
          },
          'timeline_billing_text': {
            'one': {'en': 'In {day} Day – Billing Starts'},
            'other': {'en': 'In {day} Days – Billing Starts'},
          },
        }),
        now: now,
        plan: 'Premium',
        price: r'$19.99/mo',
        locale: 'en',
      );
      expect(rows[1].title, 'In 1 Day – Reminder');
      expect(rows[2].title, 'In 2 Days – Billing Starts');
    });

    test('a longer trial moves the reminder and the billing day with it', () {
      final rows = PaywallTimelineBuilder.build(
        config: _config(trialDays: 7),
        now: now,
        plan: 'Premium',
        price: r'$6.99/wk',
        locale: 'en',
      );
      expect(rows.map((r) => r.day), [0, 6, 7]);
      expect(rows[2].title, 'Day 7 · Sep 18, 2025');
    });

    test('each row can be worded independently', () {
      final rows = PaywallTimelineBuilder.build(
        config: _config(trialDays: 7, extra: {
          'timeline_today_text': {'en': 'Start · {date}'},
          'timeline_billing_subtitle': {'en': 'You pay {price} on {date}'},
        }),
        now: now,
        plan: 'Premium',
        price: r'$6.99/wk',
        locale: 'en',
      );
      expect(rows.map((r) => r.day), [0, 6, 7]);
      expect(rows[0].title, 'Start · Sep 11, 2025');
      expect(rows[1].title, 'Day 6 · Sep 17, 2025');
      expect(rows[2].subtitle, r'You pay $6.99/wk on Sep 18, 2025');
    });

    test('tidies the copy when no price is available', () {
      final rows = PaywallTimelineBuilder.build(
        config: _config(trialTimeline: _remoteTimeline),
        now: now,
        plan: 'Premium',
        price: null,
        locale: 'en',
      );
      expect(rows[2].subtitle, 'Billing starts at unless cancelled');
    });

    test('uses a custom date formatter when provided', () {
      final rows = PaywallTimelineBuilder.build(
        config: _config(trialTimeline: _remoteTimeline),
        now: now,
        plan: 'Premium',
        price: r'$6.99/wk',
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

    test('the timeline spells the year out, since it names the day money moves', () {
      expect(PaywallDates.monthDayYear(DateTime(2025, 9, 11), locale: 'en'), 'Sep 11, 2025');
      expect(PaywallDates.monthDayYear(DateTime(2025, 9, 11), locale: 'xx-YY'), 'Sep 11, 2025');
    });
  });

  group('PaywallHints', () {
    final hints = _config().contextHints;

    test('free entries pick the "free" hint', () {
      expect(PaywallHints.hintFor(hints, PaywallEntry.expressFree)?.toJson(),
          {'en': 'Express and Pro need the full wizard.'});
      expect(PaywallHints.hintFor(hints, PaywallEntry.proFree)?.toJson(),
          {'en': 'Express and Pro need the full wizard.'});
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
    final monthly = config.options.firstWhere((o) => o.id == 'monthly');
    final weekly = config.options.firstWhere((o) => o.id == 'weekly');

    test('uses the store product whose key is the option id and appends the period suffix', () {
      final products = [
        _product(key: 'monthly', price: r'$19.99'),
        _product(key: 'weekly', price: r'$6.99'),
      ];
      expect(PaywallPricing.priceFor(monthly, products), r'$19.99/mo');
      expect(PaywallPricing.priceFor(weekly, products), r'$6.99/wk');
    });

    test('a single product of the tier still matches when the config has no keys', () {
      final products = [_product(price: r'$8.49')];
      expect(PaywallPricing.priceFor(monthly, products), r'$8.49/mo');
    });

    test('falls back to price_label when several tier products carry no key', () {
      final products = [_product(price: r'$19.99', id: 'a'), _product(price: r'$6.99', id: 'b')];
      expect(PaywallPricing.priceFor(monthly, products), r'$19.99/mo');
      expect(PaywallPricing.priceFor(weekly, products), r'$6.99/wk');
    });

    test('falls back to price_label when the store price is empty', () {
      final products = [_product(key: 'monthly', price: '  ')];
      expect(PaywallPricing.priceFor(monthly, products), r'$19.99/mo');
    });

    test('returns null when neither a store price nor a label exists', () {
      final bare = PaywallOption(
        id: 'monthly',
        tier: 'premium',
        title: const MultilocaleText('Monthly'),
        description: const MultilocaleText(''),
      );
      expect(PaywallPricing.priceFor(bare, const []), isNull);
    });

    test('resolves a multilocale price_label through the resolver', () {
      final option = PaywallOption(
        id: 'monthly',
        tier: 'premium',
        title: const MultilocaleText('Monthly'),
        description: const MultilocaleText(''),
        priceLabel: const MultilocaleText({'en': r'$19.99/mo', 'es': r'19,99 $/mes'}),
      );
      expect(PaywallPricing.priceFor(option, const []), r'$19.99/mo');
      expect(
        PaywallPricing.priceFor(option, const [], resolve: (v) => (v as MultilocaleText).toJson()['es']),
        r'19,99 $/mes',
      );
    });
  });

  group('PaywallPricing.productIdFor', () {
    final weekly = _config().options.firstWhere((o) => o.id == 'weekly');

    test('buys the store product matched by key', () {
      final products = [
        _product(key: 'monthly', id: 'store.monthly'),
        _product(key: 'weekly', id: 'store.weekly'),
      ];
      expect(PaywallPricing.productIdFor(weekly, products), 'store.weekly');
    });

    test('is null until the products are loaded', () {
      expect(PaywallPricing.productIdFor(weekly, const []), isNull);
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

    test('a configured reminder step asks for the permission', () {
      final steps = _config(extra: {
        'steps': [
          {'id': 'intro', 'button_text': {'en': 'Continue'}},
          {
            'id': 'reminder',
            'button_text': {'en': 'Continue'},
            'button_action': 'request_permission',
          },
        ],
      }).steps;
      expect(steps.map((s) => s.asksNotificationPermission), [false, true]);
    });

    test('an offer without a trial has no explainer steps', () {
      expect(_config(trialDays: 0).steps, isEmpty);
    });
  });
}
