import 'dart:convert';
import 'dart:io';

import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/domain/entities/onboarding_data_entity.dart';
import 'package:appwizard/features/onboarding/domain/logic/onboarding_answer_flattener.dart';
import 'package:flutter_test/flutter_test.dart';

List<OnboardingModel> _defaultScreens() {
  final root = jsonDecode(File('assets/config/remote_config_defaults.json').readAsStringSync()) as Map<String, dynamic>;
  final list = jsonDecode(root['onboarding_screens'] as String) as List;
  return list.map((e) => OnboardingModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
}

void main() {
  final screens = _defaultScreens();

  test('records the options each screen offered next to the answer', () {
    final answers = OnboardingAnswerFlattener.flatten(screens, {
      0: ['starting', 'fair_price'], // multi_select
      1: 'tactical', // select (vibe)
      2: 60, // slider_lottie (push)
      3: {'favorite_marketplace': 'ebay', 'deals_per_month': '3_5'}, // select_group
      4: 550, // slider (deal size)
      7: 'FRIEND-42', // referral_code
    });
    final byKey = {for (final a in answers) a.answerKey!: a};

    expect(byKey['main_hurdle']!.options, ['starting', 'counter_offers', 'being_rude', 'holding_ground', 'fair_price']);
    expect(byKey['negotiation_vibe']!.options, ['friendly', 'no_nonsense', 'tactical', 'quiet_closer']);
    expect(byKey['risk_tolerance']!.options, ['20', '40', '60', '80', '100']);
    expect(byKey['favorite_marketplace']!.options, ['ebay', 'amazon', 'facebook', 'olx', 'craigslist', 'other']);
    expect(byKey['deals_per_month']!.options, ['0_2', '3_5', '6_plus']);
    expect(byKey['average_deal_size']!.options, ['50', '550', '5000']);
    expect(byKey['referral_code']!.options, isNull);
  });

  test('options survive the entity JSON round trip', () {
    final a = OnboardingAnswerFlattener.flatten(screens, {1: 'friendly'}).single;
    final copy = OnboardingAnswer.fromJson(a.toJson());
    expect(copy, a);
    expect(copy.options, isNotNull);
  });
}
