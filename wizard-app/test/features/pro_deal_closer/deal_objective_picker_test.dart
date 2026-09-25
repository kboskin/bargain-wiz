import 'dart:convert';
import 'dart:io';

import 'package:appwizard/features/home/data/models/main_page_config.dart';
import 'package:appwizard/features/pro_deal_closer/presentation/widgets/deal_objective_picker.dart';
import 'package:appwizard/features/shared/data/models/deal_objective.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const start = 'Objective: start the chat.';
  const discount = 'Objective: get a discount.';
  final objectives = [
    DealObjective.fromJson(const {'emoji': '👋', 'label': {'en': 'Start the chat'}, 'prompt': start}),
    DealObjective.fromJson(const {'label': 'Get a discount', 'prompt': discount}),
    // No text, nothing to tell the model: never offered.
    DealObjective.fromJson(const {'label': 'Empty'}),
  ];

  Future<void> pump(
    final WidgetTester tester, {
    final String? selected,
    final ValueChanged<String>? onSelect,
  }) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DealObjectivePicker(
              title: "What's the goal for this chat?",
              objectives: objectives,
              selected: selected,
              onSelect: onSelect,
            ),
          ),
        ),
      );

  testWidgets('offers every objective with text, and picking one hands over that text',
      (final tester) async {
    final picked = <String>[];
    await pump(tester, onSelect: picked.add);

    expect(find.text("What's the goal for this chat?"), findsOneWidget);
    expect(find.text('👋 Start the chat'), findsOneWidget);
    expect(find.text('Get a discount'), findsOneWidget);
    expect(find.text('Empty'), findsNothing);

    await tester.tap(find.text('Get a discount'));
    expect(picked, [discount]);
  });

  testWidgets('once the chat exists, only the picked objective stays', (final tester) async {
    await pump(tester, selected: discount);

    expect(find.text('Get a discount'), findsOneWidget);
    expect(find.text('👋 Start the chat'), findsNothing);
  });

  testWidgets('and nothing at all when none was picked', (final tester) async {
    await pump(tester);

    expect(find.byType(Text), findsNothing);
  });

  test('the bundled template offers three objectives, each with its text and a label', () {
    final defaults = jsonDecode(File('assets/config/remote_config_defaults.json').readAsStringSync())
        as Map<String, dynamic>;
    final config = MainPageConfig.fromJson(
      jsonDecode(defaults['main_page_config'] as String) as Map<String, dynamic>,
    );

    expect(config.dealCloserObjectives, hasLength(3));
    for (final objective in config.dealCloserObjectives) {
      expect(objective.prompt, startsWith('Objective: '));
      expect(objective.label, isNotNull, reason: objective.prompt);
    }
  });
}
