import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/profile/domain/profile_fields.dart';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';

/// The bundled defaults are what ships when Remote Config has nothing to say, so the
/// Profile rows are asserted against them rather than a fixture.
List<OnboardingModel> _defaultScreens() {
  final root = jsonDecode(File('assets/config/remote_config_defaults.json').readAsStringSync())
      as Map<String, dynamic>;
  final raw = root['onboarding_screens'];
  final list = (raw is String ? jsonDecode(raw) : raw) as List;
  return list.map((e) => OnboardingModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
}

/// Stand-in for `TemplateText.textOf`, which needs a BuildContext.
String _resolve(dynamic value) {
  if (value == null) return '';
  if (value is MultilocaleText) return _resolve(value.toJson());
  if (value is Map) return value['en']?.toString() ?? '';
  return value.toString();
}

void main() {
  late List<OnboardingModel> screens;

  setUpAll(() => screens = _defaultScreens());

  group('ProfileFields.fromScreens', () {
    test('covers every answer the default onboarding asks for, in order', () {
      final fields = ProfileFields.fromScreens(screens);
      expect(fields.map((f) => f.key), [
        'hurdles',
        'vibe',
        'push',
        'marketplace',
        'deals_per_month',
        'deal_size',
        'referral_code',
      ]);
    });

    test('skips the answers that have a card of their own', () {
      final fields = ProfileFields.fromScreens(
        screens,
        skip: const {'vibe', 'push'},
      );
      expect(fields.map((f) => f.key), [
        'hurdles',
        'marketplace',
        'deals_per_month',
        'deal_size',
        'referral_code',
      ]);
    });

    test('skips the answers onboarding locks, so the referral code cannot be re-set', () {
      expect(ProfileFields.lockedKeys, contains('referral_code'));
      final fields = ProfileFields.fromScreens(
        screens,
        skip: {'vibe', 'push', ...ProfileFields.lockedKeys},
      );
      expect(fields.map((f) => f.key), [
        'hurdles',
        'marketplace',
        'deals_per_month',
        'deal_size',
      ]);
    });

    test('kinds follow the screen template', () {
      final byKey = {for (final f in ProfileFields.fromScreens(screens)) f.key: f};
      expect(byKey['hurdles']!.kind, ProfileFieldKind.multi);
      expect(byKey['hurdles']!.minSelected, 1);
      expect(byKey['vibe']!.kind, ProfileFieldKind.single);
      expect(byKey['marketplace']!.kind, ProfileFieldKind.single);
      expect(byKey['referral_code']!.kind, ProfileFieldKind.text);
      expect(byKey['referral_code']!.uppercase, isTrue);
      expect(_resolve(byKey['referral_code']!.placeholder), 'Enter code');
    });

    test('slider stops become numeric options', () {
      final byKey = {for (final f in ProfileFields.fromScreens(screens)) f.key: f};
      final push = byKey['push']!;
      expect(push.numeric, isTrue);
      expect(push.options.map((o) => o.value), ['20', '40', '60', '80', '100']);
      final dealSize = byKey['deal_size']!;
      expect(dealSize.numeric, isTrue);
      expect(dealSize.options.map((o) => o.value), ['50', '550', '5000']);
      expect(_resolve(dealSize.options[1].label), r'$100–1000');
      expect(ProfileFields.storedValue(dealSize, '550'), 550);
      expect(ProfileFields.storedValue(byKey['deals_per_month']!, '3_5'), '3_5');
    });

    test('select_group groups become one field each, labelled by the group', () {
      final byKey = {for (final f in ProfileFields.fromScreens(screens)) f.key: f};
      final marketplace = byKey['marketplace']!;
      expect(_resolve(marketplace.label), 'Primary platform');
      expect(marketplace.options.map((o) => o.value),
          ['ebay', 'amazon', 'facebook', 'olx', 'craigslist', 'other']);
      expect((marketplace.options.first.iconRaw as Map)['code'], '0xf4f4');
      expect(byKey['deals_per_month']!.options.map((o) => o.value), ['0_2', '3_5', '6_plus']);
    });

    test('labels prefer the short profile_label over the screen question', () {
      final byKey = {for (final f in ProfileFields.fromScreens(screens)) f.key: f};
      expect(_resolve(byKey['hurdles']!.label), 'Money leaks');
      expect(_resolve(byKey['deal_size']!.label), 'Typical deal size');
      expect(_resolve(byKey['push']!.label), 'How hard you push');
    });

    test('falls back to the screen title when no profile_label is configured', () {
      final screen = OnboardingModel.fromJson({
        'type': 'select',
        'title': {'en': 'Who negotiates for you?'},
        'answer_structure': {'answer_key_name': 'vibe'},
        'options': [
          {'label': 'Friendly Collaborator', 'value': 'friendly'},
        ],
      });
      final field = ProfileFields.fromScreens([screen]).single;
      expect(_resolve(field.label), 'Who negotiates for you?');
      expect(field.options.single.value, 'friendly');
    });

    test('screens that ask nothing produce no field', () {
      final informational = screens.where((s) => s.answerKeys.isEmpty).toList();
      expect(informational, isNotEmpty);
      expect(ProfileFields.fromScreens(informational), isEmpty);
    });
  });

  group('ProfileFields.displayValue', () {
    late Map<String, ProfileField> byKey;

    setUpAll(() => byKey = {for (final f in ProfileFields.fromScreens(screens)) f.key: f});

    test('single: the option label, the raw value when it is gone, — when unanswered', () {
      final field = byKey['marketplace']!;
      expect(ProfileFields.displayValue(field, 'ebay', _resolve), 'eBay');
      expect(ProfileFields.displayValue(field, 'retired', _resolve), 'retired');
      expect(ProfileFields.displayValue(field, null, _resolve), '—');
    });

    test('single numeric: the stop label for an int answer', () {
      expect(ProfileFields.displayValue(byKey['deal_size']!, 550, _resolve), r'$100–1000');
    });

    test('multi: the label for one pick, a count beyond that', () {
      final field = byKey['hurdles']!;
      expect(ProfileFields.displayValue(field, const ['being_rude'], _resolve),
          "I felt awkward, so I didn't push");
      expect(ProfileFields.displayValue(field, const ['being_rude', 'fair_price'], _resolve),
          '2 selected');
      expect(ProfileFields.displayValue(field, const <String>[], _resolve), '—');
      expect(ProfileFields.valuesOf('being_rude'), ['being_rude']);
      expect(ProfileFields.valuesOf(null), isEmpty);
    });

    test('text: the code itself, — when blank', () {
      final field = byKey['referral_code']!;
      expect(ProfileFields.displayValue(field, 'FRIEND-42', _resolve), 'FRIEND-42');
      expect(ProfileFields.displayValue(field, '  ', _resolve), '—');
    });
  });

  test('nothing configured means no rows (remote config owns the keys)', () {
    expect(ProfileFields.fromScreens(const []), isEmpty);
  });
}
