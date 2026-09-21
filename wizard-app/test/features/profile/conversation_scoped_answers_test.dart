/// The mechanism behind a deal's own answers: which ones a conversation may carry its own
/// value for, and in what order.
///
/// Nothing in either half names `vibe` or `marketplace` — the template marks an answer
/// `scope: "conversation"` and the filter follows. These tests use made-up keys on purpose:
/// if they ever need a real one to pass, the genericity has been lost.
import 'package:flutter_test/flutter_test.dart';

import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_screen_config.dart';
import 'package:appwizard/features/profile/domain/profile_fields.dart';

OnboardingModel _select(String key, List<String> values, {String? scope}) => SelectScreenModel(
      title: 'Pick one',
      description: 'Pick one',
      nextButtonText: 'Next',
      answerStructure: AnswerStructure(answerKeyName: key, scope: scope),
      options: [
        for (final v in values)
          OnboardingOption(
            label: v.toUpperCase(),
            value: v,
            metadata: OnboardingMetadata.fromOptionalMap({'color': '#4ECDC4', 'short': v}),
          ),
      ],
    );

void main() {
  group('which answers a deal may override', () {
    test('only the ones the template scopes to a conversation, in screen order', () {
      final fields = ProfileFields.fromScreens([
        _select('brand_new_question', ['a', 'b'], scope: 'conversation'),
        _select('about_the_person', ['x']),
        _select('another_deal_answer', ['y'], scope: 'CONVERSATION'), // case is not the point
      ]);

      expect(
        ProfileFields.conversationScoped(fields).map((f) => f.key),
        ['brand_new_question', 'another_deal_answer'],
      );
    });

    test('an answer with no scope is the person\'s, so no deal carries it', () {
      final fields = ProfileFields.fromScreens([_select('about_the_person', ['x'])]);

      expect(ProfileFields.conversationScoped(fields), isEmpty);
    });

    test('the screen template travels with the field, so the Profile screen can pick a widget', () {
      final fields = ProfileFields.fromScreens([_select('anything', ['a'])]);

      expect(fields.single.template, OnboardingScreenType.select);
    });
  });
}
