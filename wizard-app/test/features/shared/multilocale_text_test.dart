import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';
import 'package:appwizard/features/shared/data/models/plural_text.dart';

void main() {
  Widget host(Locale locale, WidgetBuilder builder) => MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('es')],
        home: Builder(builder: builder),
      );

  group('MultilocaleText', () {
    testWidgets('returns the current locale and falls back to en', (tester) async {
      String? es;
      String? fallback;
      await tester.pumpWidget(host(const Locale('es'), (context) {
        es = MultilocaleText.fromJson({'en': 'Hello', 'es': 'Hola'}).get(context);
        fallback = MultilocaleText.fromJson({'en': 'Only English'}).get(context);
        return const SizedBox();
      }));
      expect(es, 'Hola');
      expect(fallback, 'Only English');
    });

    testWidgets('accepts a plain string', (tester) async {
      String? s;
      await tester.pumpWidget(host(const Locale('en'), (context) {
        s = MultilocaleText.fromJson('Plain').get(context);
        return const SizedBox();
      }));
      expect(s, 'Plain');
    });
  });

  group('PluralText', () {
    testWidgets('resolves one/other and replaces {n}', (tester) async {
      final p = PluralText.fromJson({
        'one': {'en': 'Read 1 screenshot'},
        'other': {'en': 'Read {n} screenshots'},
      })!;
      String? one;
      String? three;
      await tester.pumpWidget(host(const Locale('en'), (context) {
        one = p.get(context, 1);
        three = p.get(context, 3);
        return const SizedBox();
      }));
      expect(one, 'Read 1 screenshot');
      expect(three, 'Read 3 screenshots');
    });

    testWidgets('accepts a simple multilocale value', (tester) async {
      final p = PluralText.fromJson({'en': 'Attach {n}'})!;
      String? s;
      await tester.pumpWidget(host(const Locale('en'), (context) {
        s = p.get(context, 2);
        return const SizedBox();
      }));
      expect(s, 'Attach 2');
    });

    test('null stays null', () {
      expect(PluralText.fromJson(null), isNull);
    });
  });
}
