import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_screen_config.dart';
import 'package:appwizard/features/onboarding/domain/logic/onboarding_answer_flattener.dart';
import 'package:flutter_test/flutter_test.dart';

List<OnboardingModel> _screens() => [
      OnboardingModel.fromJson({
        'type': 'multi_select',
        'title': {'en': 'Where has your money slipped away?'},
        'options': [
          {'label': 'A', 'value': 'starting'},
          {'label': 'B', 'value': 'fair_price'},
        ],
        'answer_structure': {'answer_key_name': 'main_hurdle', 'multi': true},
      }),
      OnboardingModel.fromJson({
        'type': 'select',
        'title': 'Who negotiates for you?',
        'description': 'desc',
        'options': [
          {'label': 'Friendly Collaborator', 'value': 'friendly'},
        ],
        'answer_structure': {'answer_key_name': 'negotiation_vibe'},
      }),
      OnboardingModel.fromJson({
        'type': 'slider_lottie',
        'title': 'How hard do you push?',
        'metadata': {'options': [], 'default_value': 60},
        'answer_structure': {'answer_key_name': 'risk_tolerance'},
      }),
      OnboardingModel.fromJson({
        'type': 'select_group',
        'title': 'Where do you deal?',
        'groups': [
          {
            'label': 'Primary platform',
            'answer_key_name': 'favorite_marketplace',
            'options': [
              {'label': 'eBay', 'value': 'ebay'},
            ],
          },
          {
            'label': 'Deals per month',
            'answer_key_name': 'deals_per_month',
            'options': [
              {'label': '3–5', 'value': '3_5'},
            ],
          },
        ],
      }),
      OnboardingModel.fromJson({
        'type': 'warmup',
        'title': 'You have been leaving {monthly_leak}',
        'next_button_text': 'Stop the leak',
      }),
      OnboardingModel.fromJson({
        'type': 'referral_code',
        'title': 'Enter Referral Code',
        'answer_structure': {'answer_key_name': 'referral_code'},
      }),
    ];

void main() {
  group('OnboardingAnswerFlattener', () {
    test('expands multi-key (select_group) answers into one answer per key', () {
      final answers = <int, dynamic>{
        0: ['starting', 'fair_price'],
        1: 'friendly',
        2: 60,
        3: {'favorite_marketplace': 'ebay', 'deals_per_month': '3_5'},
        5: 'WIZ42',
      };
      final flat = OnboardingAnswerFlattener.flatten(_screens(), answers);

      expect(flat.map((a) => a.answerKey), [
        'main_hurdle',
        'negotiation_vibe',
        'risk_tolerance',
        'favorite_marketplace',
        'deals_per_month',
        'referral_code',
      ]);
      final byKey = {for (final a in flat) a.answerKey: a};
      expect(byKey['main_hurdle']!.answer, ['starting', 'fair_price']);
      expect(byKey['favorite_marketplace']!.answer, 'ebay');
      expect(byKey['favorite_marketplace']!.screenIndex, 3);
      expect(byKey['favorite_marketplace']!.screenType, OnboardingScreenType.selectGroup);
      expect(byKey['deals_per_month']!.answer, '3_5');
      expect(byKey['risk_tolerance']!.answer, 60);
      expect(byKey['referral_code']!.answer, 'WIZ42');
    });

    test('skips blank values, unknown keys, and out-of-range indices', () {
      final answers = <int, dynamic>{
        3: {'favorite_marketplace': 'olx', 'unknown': 'x', 'deals_per_month': null},
        5: '   ',
        42: 'nope',
      };
      final flat = OnboardingAnswerFlattener.flatten(_screens(), answers);
      expect(flat.length, 1);
      expect(flat.single.answerKey, 'favorite_marketplace');
      expect(flat.single.answer, 'olx');
    });

    test('byKey exposes the flattened map used by warmup / data_upload', () {
      final byKey = OnboardingAnswerFlattener.byKey(_screens(), {
        1: 'tactical',
        3: {'favorite_marketplace': 'facebook', 'deals_per_month': '6_plus'},
      });
      expect(byKey, {
        'negotiation_vibe': 'tactical',
        'favorite_marketplace': 'facebook',
        'deals_per_month': '6_plus',
      });
    });
  });
}
