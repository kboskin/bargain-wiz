import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appwizard/features/profile/domain/profile_fields.dart';
import 'package:appwizard/features/profile/presentation/widgets/profile_answer_sheets.dart';

void main() {
  const hurdles = [
    ProfileOption('starting', 'I paid full price'),
    ProfileOption('counter_offers', 'The seller ignored my offer'),
    ProfileOption('being_rude', {'en': 'I felt awkward', 'es': 'Me sentí incómodo'}),
  ];

  Widget host(void Function(BuildContext context) open) => MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('es')],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(onPressed: () => open(context), child: const Text('open')),
          ),
        ),
      );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('showProfileMultiSelectSheet', () {
    testWidgets('saves the picks in tap order, keeping what was already picked', (tester) async {
      List<String>? saved;
      await tester.pumpWidget(host((context) => showProfileMultiSelectSheet(
            context,
            title: 'Money leaks',
            options: hurdles,
            selected: const ['starting'],
            onSave: (values) => saved = values,
          )));
      await openSheet(tester);

      expect(find.text('Money leaks'), findsOneWidget);
      expect(find.text('I felt awkward'), findsOneWidget); // multilocale label resolved

      await tester.tap(find.text('The seller ignored my offer'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(saved, ['starting', 'counter_offers']);
      expect(find.text('Money leaks'), findsNothing); // sheet closed
    });

    testWidgets('untaps a pick and refuses to save below min_selected', (tester) async {
      var saves = 0;
      await tester.pumpWidget(host((context) => showProfileMultiSelectSheet(
            context,
            title: 'Money leaks',
            options: hurdles,
            selected: const ['starting'],
            minSelected: 1,
            onSave: (_) => saves++,
          )));
      await openSheet(tester);

      await tester.tap(find.text('I paid full price'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(saves, 0);
      expect(find.text('Money leaks'), findsOneWidget); // still open
    });
  });

  group('showProfileTextSheet', () {
    testWidgets('trims and upper-cases a code', (tester) async {
      String? saved;
      await tester.pumpWidget(host((context) => showProfileTextSheet(
            context,
            title: 'Referral code',
            value: 'old',
            uppercase: true,
            onSave: (text) => saved = text,
          )));
      await openSheet(tester);

      await tester.enterText(find.byType(TextField), '  friend-42 ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(saved, 'FRIEND-42');
    });
  });

  group('showProfileOptionSheet', () {
    testWidgets('pops with the picked value', (tester) async {
      String? picked;
      await tester.pumpWidget(host((context) => showProfileOptionSheet(
            context,
            title: 'Primary marketplace',
            options: const [ProfileOption('ebay', 'eBay'), ProfileOption('amazon', 'Amazon')],
            selected: 'ebay',
            onPick: (value) => picked = value,
          )));
      await openSheet(tester);

      await tester.tap(find.text('Amazon'));
      await tester.pumpAndSettle();

      expect(picked, 'amazon');
      expect(find.text('Primary marketplace'), findsNothing);
    });
  });
}
