/// The mechanism behind the deal-header chips: which answers a conversation may carry its
/// own value for, and the button that shows one.
///
/// Nothing in either half names `vibe` or `marketplace` — the template marks an answer
/// `scope: "conversation"` and both the filter and the chip follow. These tests use made-up
/// keys on purpose: if they ever need a real one to pass, the genericity has been lost.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_screen_config.dart';
import 'package:appwizard/features/pro_deal_closer/presentation/widgets/profile_chip_button.dart';
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

    test('an answer with no scope is the person\'s, so no chip offers it', () {
      final fields = ProfileFields.fromScreens([_select('about_the_person', ['x'])]);

      expect(ProfileFields.conversationScoped(fields), isEmpty);
    });

    test('the screen template travels with the field, so the Profile screen can pick a widget', () {
      final fields = ProfileFields.fromScreens([_select('anything', ['a'])]);

      expect(fields.single.template, OnboardingScreenType.select);
    });
  });

  group('ProfileChipButton', () {
    testWidgets('shows the picked option\'s short label and cycles on tap', (tester) async {
      final field = ProfileFields.fromScreens([
        _select('brand_new_question', ['alpha', 'beta'], scope: 'conversation'),
      ]).single;
      String? tapped;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ProfileChipButton(
            option: field.optionFor('alpha'),
            onTap: () => tapped = 'alpha',
          ),
        ),
      ));

      expect(find.text('alpha ▾'), findsOneWidget);
      await tester.tap(find.byType(ProfileChipButton));
      expect(tapped, 'alpha');
    });

    testWidgets('renders nothing for a value the config no longer offers', (tester) async {
      final field = ProfileFields.fromScreens([
        _select('brand_new_question', ['alpha'], scope: 'conversation'),
      ]).single;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ProfileChipButton(option: field.optionFor('retired'), onTap: () {})),
      ));

      expect(find.byType(Text), findsNothing);
    });
  });
}
