import 'dart:ui' show Color;

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/domain/logic/onboarding_profile_snapshot.dart';
import 'package:appwizard/features/profile/domain/profile_fields.dart';
import 'package:flutter_test/flutter_test.dart';

/// The screens a warmup placeholder resolves against: the answer key is the placeholder name,
/// and every attribute the derived placeholders need (emoji, colour, savings) is on the
/// options, exactly as remote config sends them.
List<ProfileField> _fields() => ProfileFields.fromScreens([
      OnboardingModel.fromJson({
        'type': 'multi_select',
        'title': {'en': 'Where has your money slipped away?'},
        'answer_structure': {'answer_key_name': 'hurdles', 'multi': true},
        'metadata': {'min_selected': 1},
        'options': [
          {'label': {'en': 'Starting the chat'}, 'value': 'starting'},
          {'label': {'en': 'A fair price'}, 'value': 'fair_price'},
        ],
      }),
      OnboardingModel.fromJson({
        'type': 'select',
        'title': {'en': 'Who negotiates for you?'},
        'answer_structure': {'answer_key_name': 'vibe'},
        'options': [
          {
            'label': {'en': 'Friendly Collaborator', 'es': 'Colaborador Amable'},
            'value': 'friendly',
            'metadata': {'color': '#4ECDC4', 'short': {'en': 'Friendly', 'es': 'Amable'}},
          },
          {
            'label': {'en': 'Tactical Strategist'},
            'value': 'tactical',
            'metadata': {'short': {'en': 'Tactical'}},
          },
        ],
      }),
      OnboardingModel.fromJson({
        'type': 'slider_lottie',
        'title': {'en': 'How hard do you push?'},
        'answer_structure': {'answer_key_name': 'push'},
        'metadata': {
          'options': [
            {'value': 20, 'label': {'en': 'Easygoing'}, 'emoji': '🌊', 'color': '#C026D3'},
            {'value': 60, 'label': {'en': 'Balanced', 'es': 'Equilibrado'}, 'emoji': '⚖️', 'color': '#0EA5E9'},
          ],
          'default_value': 60,
        },
      }),
      OnboardingModel.fromJson({
        'type': 'select_group',
        'title': {'en': 'Where do you deal?'},
        'next_button_text': 'Continue',
        'groups': [
          {
            'label': 'Primary platform',
            'answer_key_name': 'marketplace',
            'options': [
              {'label': 'Facebook Marketplace', 'value': 'facebook'},
              {'label': 'eBay', 'value': 'ebay'},
            ],
          },
          {
            'label': 'Deals per month',
            'answer_key_name': 'deals_per_month',
            'options': [
              {'label': '0–2', 'value': '0_2'},
              {'label': '3–5', 'value': '3_5'},
            ],
          },
        ],
      }),
      OnboardingModel.fromJson({
        'type': 'slider',
        'title': {'en': "What's a typical deal for you?"},
        'answer_structure': {'answer_key_name': 'deal_size'},
        'metadata': {
          'options': [
            {'value': 550, 'label': r'$100–1000', 'savings_low': 45, 'savings_high': 110},
            {'value': 5000, 'label': r'$1000+', 'savings_low': 300, 'savings_high': 900},
          ],
        },
      }),
    ]);

void main() {
  final fields = _fields();
  const multiplier = {'0_2': 2, '3_5': 5, '6_plus': 8};

  group('OnboardingProfileSnapshot.formatMoney', () {
    test('adds a dollar sign and thousands separators', () {
      expect(OnboardingProfileSnapshot.formatMoney(0), r'$0');
      expect(OnboardingProfileSnapshot.formatMoney(550), r'$550');
      expect(OnboardingProfileSnapshot.formatMoney(7200), r'$7,200');
      expect(OnboardingProfileSnapshot.formatMoney(1234567), r'$1,234,567');
    });
  });

  group('monthly leak', () {
    test('uses savings_high(deal size) × multiplier(deals per month)', () {
      final s = OnboardingProfileSnapshot(
        answers: const {'deal_size': 550, 'deals_per_month': '3_5'},
        fields: fields,
        dealsMultiplier: multiplier,
      );
      expect(s.monthlyLeak, 110 * 5);
      expect(s.monthlyLeakText, r'$550');
    });

    test('formats large leaks with a separator', () {
      final s = OnboardingProfileSnapshot(
        answers: const {'deal_size': 5000, 'deals_per_month': '6_plus'},
        fields: fields,
        dealsMultiplier: multiplier,
      );
      expect(s.monthlyLeak, 900 * 8);
      expect(s.monthlyLeakText, r'$7,200');
    });

    test('is nothing until both answers are in', () {
      final s = OnboardingProfileSnapshot(answers: const {}, fields: fields, dealsMultiplier: multiplier);
      expect(s.monthlyLeak, 0);
      expect(
        OnboardingProfileSnapshot(answers: const {'deal_size': 550}, fields: fields).monthlyLeak,
        0,
      );
    });
  });

  group('placeholders and chips', () {
    final answers = <String, dynamic>{
      'hurdles': ['starting', 'fair_price'],
      'vibe': 'friendly',
      'push': 60,
      'marketplace': 'facebook',
      'deals_per_month': '3_5',
      'deal_size': 550,
    };

    OnboardingProfileSnapshot snapshot({String languageCode = 'en'}) => OnboardingProfileSnapshot(
          answers: answers,
          fields: fields,
          languageCode: languageCode,
          dealsMultiplier: multiplier,
        );

    test('every answer is a placeholder of its own key, lower-cased in body copy', () {
      final s = snapshot();
      final body = s.fillBody(
        'A {vibe} wizard with a {push} push saves {savings} on a typical {deal_size} deal on {marketplace}.',
      );
      expect(
        body,
        r'A friendly wizard with a balanced push saves $45–110 on a typical $100–1000 deal on facebook marketplace.',
      );
      expect(s.bodyPlaceholders['monthly_leak'], r'$550');
    });

    test('summary chips keep casing, fill emoji/count and take the option colour', () {
      final chips = snapshot().chips(const [
        '{vibe} wizard',
        '{push_emoji} {push}',
        '{marketplace}',
        '{leak_count} money leaks → plugged',
      ]);
      expect(chips.map((c) => c.label), [
        'Friendly wizard',
        '⚖️ Balanced',
        'Facebook Marketplace',
        '2 money leaks → plugged',
      ]);
      expect(chips[0].background, const Color(0xFF4ECDC4)); // the vibe option's colour
      expect(chips[1].background, const Color(0xFF0EA5E9)); // the push stop's colour
      expect(chips[1].foreground, const Color(0xFFFFFFFF)); // dark chip → white label
      expect(chips[3].background, const Color(0xD9FFFFFF)); // no colour configured
      expect(chips[3].foreground, WizColors.ink); // light chip → ink label
    });

    test('an unanswered screen leaves its placeholder empty and drops the chip', () {
      final s = OnboardingProfileSnapshot(answers: const {}, fields: fields);
      expect(s.fillChip('{leak_count} money leaks → plugged'), 'Money leaks → plugged');
      expect(s.fillChip('{marketplace}'), '');
      expect(s.chips(const ['{marketplace}']), isEmpty);
    });

    test('labels follow the locale', () {
      final s = snapshot(languageCode: 'es');
      expect(s.chipPlaceholders['vibe'], 'Amable');
      expect(s.chipPlaceholders['push'], 'Equilibrado');
      expect(s.fillChip('Mago {vibe}'), 'Mago Amable');
    });
  });
}
