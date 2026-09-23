import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appwizard/features/paywall/data/models/paywall_config.dart';
import 'package:appwizard/features/paywall/data/models/paywall_layout.dart';
import 'package:appwizard/features/paywall/domain/paywall_copy.dart';
import 'package:appwizard/features/paywall/presentation/widgets/paywall_plan_layouts.dart';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';
import 'package:appwizard/features/subscription/data/models/subscription_config.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';

/// The offer as it actually ships in `assets/config/remote_config_defaults.json`.
///
/// The paywall is a Remote Config template, so the bundled defaults are the offer every
/// first launch sees — a typo there is a broken paywall, not a broken screen. These parse the
/// real asset rather than a fixture.
void main() {
  late PaywallConfig paywall;
  late SubscriptionConfig subscriptions;

  setUpAll(() {
    final raw = File('assets/config/remote_config_defaults.json').readAsStringSync();
    final defaults = jsonDecode(raw) as Map<String, dynamic>;
    paywall = PaywallConfig.fromJson(
      jsonDecode(defaults['paywall_config'] as String) as Map<String, dynamic>,
    );
    subscriptions = SubscriptionConfig.fromJson(
      jsonDecode(defaults['subscription_config'] as String) as Map<String, dynamic>,
    );
  });

  test('one paid plan, sold monthly (preselected) and weekly', () {
    expect(paywall.options.map((o) => o.id), ['monthly', 'weekly']);
    expect(paywall.options.map((o) => o.tierEnum), everyElement(SubscriptionTier.premium));
    expect(paywall.metadata.defaultSelectedOptionId, 'monthly');
    expect(paywall.metadata.layout, PaywallLayout.cards);
  });

  test('every plan unlocks the same features, whichever period you buy', () {
    final featureSets = paywall.options
        .map((o) => o.features.map(PaywallText.plain).toList())
        .toList();
    expect(featureSets.first, featureSets.last);
    // The trial is a property of a billing period, not a feature of the plan.
    for (final features in featureSets) {
      expect(features, isNot(contains(contains('free'))));
    }
  });

  group('the free trial is monthly only', () {
    test('monthly has the trial, weekly has none', () {
      final monthly = paywall.options.firstWhere((o) => o.id == 'monthly');
      final weekly = paywall.options.firstWhere((o) => o.id == 'weekly');
      expect(monthly.trialDaysOr(paywall.trialDays), greaterThan(0));
      expect(weekly.trialDays, 0, reason: 'weekly must opt out explicitly, not inherit');
      expect(weekly.trialDaysOr(paywall.trialDays), 0);
    });

    test('only the plan with a trial badges one, and the badge counts its own days', () {
      for (final option in paywall.options) {
        final days = option.trialDaysOr(paywall.trialDays);
        if (days > 0) {
          expect(option.trialBadge, isNotNull, reason: '${option.id} should badge its trial');
          expect(option.trialBadge!.sourceFor(days).toJson(), isA<Map<String, dynamic>>());
          expect(PaywallText.plain(option.trialBadge!.sourceFor(days)), contains('{n}'));
          expect(PaywallText.plain(option.trialBadge!.sourceFor(1)), isNot(contains('days')));
        } else {
          expect(option.trialBadge, isNull, reason: '${option.id} has no trial to badge');
        }
      }
    });

    test('the emphasised phrase actually appears in the description it marks', () {
      for (final option in paywall.options) {
        final words = option.descriptionHighlightWords;
        if (words == null) continue;
        final en = PaywallText.plain(option.description).toLowerCase();
        final es = (option.description.toJson() as Map)['es'].toString().toLowerCase();
        for (final phrase in words.keys) {
          expect(
            en.contains(phrase.toLowerCase()) || es.contains(phrase.toLowerCase()),
            isTrue,
            reason: '${option.id}: "$phrase" is highlighted but never written',
          );
        }
      }
    });

    test('the card copy does not repeat the badge', () {
      for (final option in paywall.options) {
        final days = option.trialDaysOr(paywall.trialDays);
        if (days > 0) {
          expect(
            PaywallText.plain(option.description),
            isNot(contains('$days days free')),
            reason: '${option.id}: the badge already says it',
          );
        }
      }
    });

    test('each period states its own terms in its note and CTA', () {
      for (final option in paywall.options) {
        final days = option.trialDaysOr(paywall.trialDays);
        final note = PaywallText.plain(option.noteText);
        final cta = PaywallText.plain(option.buttonText);
        expect(note, contains('{price}'), reason: '${option.id} note must show the price');
        expect(cta, isNotEmpty, reason: '${option.id} needs its own CTA');
        if (days > 0) {
          expect(note, contains('$days days free'));
          // The CTA promises a free start, by naming the length or the price of it.
          expect(
            cta.toLowerCase().contains('free') || cta.contains(r'$0.00'),
            isTrue,
            reason: '${option.id} CTA should say starting is free: "$cta"',
          );
        } else {
          expect(note.toLowerCase(), isNot(contains('free')));
          expect(cta.toLowerCase(), isNot(contains('free')));
          expect(cta, isNot(contains(r'$0.00')));
        }
      }
    });

    test('the paywall-wide fallbacks promise nothing an option has not', () {
      expect(PaywallText.plain(paywall.nextButtonText).toLowerCase(), isNot(contains('free')));
      expect(PaywallText.plain(paywall.noteText).toLowerCase(), isNot(contains('free')));
      expect(PaywallText.plain(paywall.noteText), contains('{price}'));
    });
  });

  test('monthly leads: first, preselected and the only badged plan', () {
    expect(paywall.options.first.id, 'monthly');
    expect(paywall.metadata.defaultSelectedOptionId, 'monthly');
    final badged = paywall.options.where(
      (o) => badgesFor(o, o.trialDaysOr(paywall.trialDays), PaywallText.plain).isNotEmpty,
    );
    expect(badged.map((o) => o.id), ['monthly']);
  });

  test('the monthly card badges the trial and nothing else', () {
    final monthly = paywall.options.firstWhere((o) => o.id == 'monthly');
    final row = badgesFor(monthly, monthly.trialDaysOr(paywall.trialDays), PaywallText.plain);
    expect(row, hasLength(1));
    expect(row.single, contains('days free'));
    // The saving is made in the description now, so it is not also a badge.
    expect(monthly.badges, isEmpty);
    expect(row.single, isNot(contains('%')));
  });

  test('any badge a card does carry has a Spanish form', () {
    for (final option in paywall.options) {
      for (final badge in option.badges) {
        expect(badge.toJson(), containsPair('es', isNotEmpty), reason: option.id);
      }
    }
  });

  test('the saving is stated once, in the monthly description', () {
    // 52 x $6.99 = $363.48 a year against 12 x $19.99 = $239.88, so monthly saves 34%.
    // The number is copy, not arithmetic: revisit it whenever either price moves.
    final monthly = paywall.options.firstWhere((o) => o.id == 'monthly');
    expect(PaywallText.plain(monthly.description), contains('34%'));
    expect(monthly.descriptionHighlightWords, isNotNull);
  });

  test('the explainer steps run intro → reminder, and the reminder asks for push', () {
    expect(paywall.steps.map((s) => s.id), ['intro', 'reminder']);
    expect(paywall.steps.map((s) => s.asksNotificationPermission), [false, true]);
    for (final step in paywall.steps) {
      expect(PaywallText.plain(step.buttonText), isNotEmpty, reason: '${step.id} needs a CTA');
      expect(step.visual, isNotNull, reason: '${step.id} needs a visual');
      // A step pointing at a file that is not there renders nothing at all.
      expect(File(step.visual!).existsSync(), isTrue,
          reason: '${step.id} -> ${step.visual} is missing');
      expect(step.visual!, anyOf(startsWith('assets/images/'), startsWith('assets/lottie/')),
          reason: '${step.id} -> ${step.visual} is outside the bundled folders');
      expect(step.artSize, greaterThan(0), reason: '${step.id} needs a drawable size');
    }
  });

  test('the timeline follows the selected period, and vanishes without a trial', () {
    expect(paywall.trialTimeline, isEmpty);
    List<PaywallTimelineRow> rowsFor(String id) {
      final option = paywall.options.firstWhere((o) => o.id == id);
      return PaywallTimelineBuilder.build(
        config: paywall,
        now: DateTime(2026, 9, 22),
        plan: 'Premium',
        price: r'$19.99/mo',
        trialDays: option.trialDaysOr(paywall.trialDays),
        locale: 'en',
      );
    }

    final monthlyDays =
        paywall.options.firstWhere((o) => o.id == 'monthly').trialDaysOr(paywall.trialDays);
    final monthly = rowsFor('monthly');
    expect(monthly.map((r) => r.day), [0, monthlyDays - 1, monthlyDays]);
    expect(rowsFor('weekly'), isEmpty);

    // The shape of the copy: relative day titles, and the billing row is the one that
    // names the amount and the exact date it is taken.
    expect(monthly.first.title, 'Today');
    expect(monthly.first.subtitle, isNotEmpty);
    expect(monthly[1].title, 'In ${monthlyDays - 1} Days – Reminder');
    expect(monthly.last.title, 'In $monthlyDays Days – Billing Starts');
    expect(monthly.last.subtitle, contains('2026'));
    expect(monthly.last.subtitle.toLowerCase(), contains('cancel'));
    // The amount is the card's to state; the timeline says when, not how much.
    expect(monthly.last.subtitle, isNot(contains(r'$19.99')));
  });

  test('each plan option buys a configured store product', () {
    final products = {for (final p in subscriptions.products) p.id: p};
    expect(products.keys, containsAll(paywall.options.map((o) => o.id)));
    for (final option in paywall.options) {
      final product = products[option.id]!;
      expect(product.tierEnum, option.tierEnum);
      expect(product.productId.ios, isNotEmpty);
      expect(product.productId.android, isNotEmpty);
    }
  });

  test('every plan option shows a billing period next to its price', () {
    for (final option in paywall.options) {
      expect(PaywallText.plain(option.priceSuffix), isNotEmpty, reason: option.id);
      expect(PaywallText.plain(option.priceLabel), isNotEmpty, reason: option.id);
    }
  });

  group('the art each plan names', () {
    test('every plan names its own, and the two differ', () {
      final visuals = paywall.metadata.optionVisuals;
      expect(visuals.keys, containsAll(paywall.options.map((o) => o.id)));
      expect(visuals.values.toSet(), hasLength(paywall.options.length),
          reason: 'two plans pointing at one file cannot look different');
    });

    test('the files exist and are bundled', () {
      for (final entry in paywall.metadata.optionVisuals.entries) {
        final path = entry.value;
        expect(File(path).existsSync(), isTrue, reason: '${entry.key} -> $path is missing');
        // assets/images/ and assets/lottie/ are both declared in pubspec.
        expect(path, anyOf(startsWith('assets/images/'), startsWith('assets/lottie/')),
            reason: '${entry.key} -> $path is outside the bundled folders');
      }
    });

    test('image art can carry transparency, so the card tint shows through', () {
      for (final entry in paywall.metadata.optionVisuals.entries) {
        final path = entry.value;
        if (!path.endsWith('.png')) continue;
        expect(
          _pngCanBeTransparent(File(path).readAsBytesSync()),
          isTrue,
          reason: '${entry.key} -> $path is opaque RGB; it would paint a block over art_color',
        );
      }
    });

    test('the animation loops and the art is sized to fill its block', () {
      final m = paywall.metadata;
      expect(m.isAnimationLooped, isTrue);
      expect(m.artWidth, greaterThan(PaywallMetadata.defaultArtSize));
      expect(m.artHeight, lessThanOrEqualTo(m.artBlockHeight));
      expect(m.artBlockHeight, greaterThan(PaywallMetadata.defaultArtBlockHeight),
          reason: 'the block has to grow for the art to');
    });

    test('nothing is heavier than the brief allows', () {
      for (final entry in paywall.metadata.optionVisuals.entries) {
        final kb = File(entry.value).lengthSync() / 1024;
        expect(kb, lessThan(400),
            reason: '${entry.key} -> ${entry.value} is ${kb.round()} KB');
      }
    });
  });

  test('the intro screen shows its animation larger than the default', () {
    final intro = paywall.steps.firstWhere((s) => s.id == 'intro');
    expect(intro.visual, endsWith('.json'), reason: 'it is an animation');
    expect(intro.artSize, greaterThan(PaywallStepConfig.defaultVisualSize));
    // The reminder step is deliberately left at the default.
    expect(paywall.steps.firstWhere((s) => s.id == 'reminder').visualSize, isNull);
  });

  test('the only context hint is the one the free gate asks for', () {
    expect(paywall.contextHints.keys, ['free']);
  });

  test('the hint and the note are hidden, but their wording is kept', () {
    expect(paywall.showContextHint, isFalse);
    expect(paywall.showNote, isFalse);
    // Hidden, not deleted: both come back with one flag and no release.
    expect(PaywallText.plain(paywall.contextHints['free']), isNotEmpty);
    expect(PaywallText.plain(paywall.noteText), isNotEmpty);
    // The note is where the trial-to-billing terms were spelled out, so the timeline that
    // carries them must still be on.
    expect(paywall.trialDays, greaterThan(0));
  });

  test('the selected card is emphasised the way the handoff drew it', () {
    expect(paywall.metadata.cardStyle, PaywallCardStyle.glow);
  });

  test('the price reads as a light detail, not a headline', () {
    final m = paywall.metadata;
    expect(m.priceSize, lessThan(m.titleSize));
    expect(m.priceSize, lessThan(m.descriptionSize));
    // Figtree is bundled from 300; Outfit stops at 500, so a light price must be the body font.
    expect(m.priceWeight, FontWeight.w300);
    expect(m.priceFamily, 'Figtree');
    expect(m.isPriceGlowing, isFalse);
  });

  test('the weight the price asks for is actually bundled', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final weight = paywall.metadata.priceFontWeight ?? 400;
    expect(
      pubspec.contains('assets/fonts/Figtree-$weight.ttf'),
      isTrue,
      reason: 'Figtree-\$weight.ttf is not in pubspec, so the price silently renders heavier',
    );
  });

  group('plan card wording', () {
    test('every line the Profile card and the drawer can show is configured', () {
      final card = paywall.planCard;
      expect(card, isNotNull, reason: 'plan_card is the only source of that wording');
      for (final entry in {
        'label': card!.label,
        'free_name': card.freeName,
        'paid_name': card.paidName,
        'free_subtitle': card.freeSubtitle,
        'trial_ends_today_subtitle': card.trialEndsTodaySubtitle,
        'renews_subtitle': card.renewsSubtitle,
        'active_subtitle': card.activeSubtitle,
        'upgrade_cta': card.upgradeCta,
        'manage_cta': card.manageCta,
      }.entries) {
        expect(PaywallText.plain(entry.value), isNotEmpty, reason: entry.key);
      }
      expect(card.trialSubtitle, isNotNull, reason: 'trial_subtitle');
    });

    test('the trial lines carry the placeholders the app fills', () {
      final card = paywall.planCard!;
      expect(PaywallText.plain(card.trialSubtitle!.sourceFor(2)), contains('{n}'));
      expect(PaywallText.plain(card.trialSubtitle!.sourceFor(2)), contains('{price}'));
      expect(PaywallText.plain(card.trialSubtitle!.sourceFor(1)), contains('{n}'));
      expect(PaywallText.plain(card.trialEndsTodaySubtitle), contains('{price}'));
      expect(PaywallText.plain(card.renewsSubtitle), contains('{date}'));
      expect(PaywallText.plain(card.renewsSubtitle), contains('{price}'));
      expect(PaywallText.plain(card.activeSubtitle), contains('{price}'));
    });

    test('the trial line has a singular form, so "1 days" cannot ship', () {
      final card = paywall.planCard!;
      expect(
        PaywallText.plain(card.trialSubtitle!.sourceFor(1)),
        isNot(PaywallText.plain(card.trialSubtitle!.sourceFor(2))),
      );
    });
  });

  test('the timeline wording is configured for every derived row', () {
    for (final entry in {
      'timeline_today_text': paywall.timelineTodayText,
      'timeline_today_subtitle': paywall.timelineTodaySubtitle,
      'timeline_reminder_text': paywall.timelineReminderText,
      'timeline_reminder_subtitle': paywall.timelineReminderSubtitle,
      'timeline_billing_text': paywall.timelineBillingText,
      'timeline_billing_subtitle': paywall.timelineBillingSubtitle,
    }.entries) {
      expect(PaywallText.plain(entry.value), isNotEmpty, reason: entry.key);
    }
  });

  test('every configured string has a Spanish form', () {
    final missing = <String>[];
    void check(String name, dynamic value) {
      final json = value is MultilocaleText ? value.toJson() : value;
      if (json is Map && (json['es'] == null || (json['es'] as String).trim().isEmpty)) {
        missing.add(name);
      }
    }

    check('title', paywall.title);
    check('description', paywall.description);
    check('next_button_text', paywall.nextButtonText);
    check('note_text', paywall.noteText);
    check('context_hints.free', paywall.contextHints['free']);
    for (final option in paywall.options) {
      check('${option.id}.title', option.title);
      check('${option.id}.description', option.description);
      check('${option.id}.price_suffix', option.priceSuffix);
      check('${option.id}.note_text', option.noteText);
      check('${option.id}.button_text', option.buttonText);
      if (option.trialBadge != null) {
        check('${option.id}.trial_badge', option.trialBadge!.sourceFor(2));
      }
      for (var i = 0; i < option.features.length; i++) {
        check('${option.id}.features[$i]', option.features[i]);
      }
    }
    for (final step in paywall.steps) {
      check('${step.id}.title', step.title);
      check('${step.id}.description', step.description);
      check('${step.id}.button_text', step.buttonText);
      check('${step.id}.note_text', step.noteText);
    }
    final card = paywall.planCard!;
    check('plan_card.free_subtitle', card.freeSubtitle);
    check('plan_card.renews_subtitle', card.renewsSubtitle);
    check('plan_card.active_subtitle', card.activeSubtitle);
    check('plan_card.upgrade_cta', card.upgradeCta);
    check('plan_card.manage_cta', card.manageCta);
    check('plan_card.trial_subtitle.other', card.trialSubtitle!.sourceFor(2));

    expect(missing, isEmpty, reason: 'these ship without Spanish');
  });
}

/// Whether a PNG is capable of transparency: true colour or greyscale **with** an alpha
/// channel, or a palette carrying a `tRNS` chunk. Read from the header rather than through an
/// image package, which is not a dependency here.
bool _pngCanBeTransparent(Uint8List bytes) {
  const rgba = 6, greyAlpha = 4, palette = 3;
  final colourType = bytes[25]; // IHDR data starts at 16; colour type is its 10th byte
  if (colourType == rgba || colourType == greyAlpha) return true;
  if (colourType != palette) return false;
  var i = 8; // past the signature
  while (i + 8 <= bytes.length) {
    final length =
        (bytes[i] << 24) | (bytes[i + 1] << 16) | (bytes[i + 2] << 8) | bytes[i + 3];
    final type = String.fromCharCodes(bytes.sublist(i + 4, i + 8));
    if (type == 'tRNS') return true;
    if (type == 'IEND') break;
    i += 12 + length; // length + type + data + crc
  }
  return false;
}
