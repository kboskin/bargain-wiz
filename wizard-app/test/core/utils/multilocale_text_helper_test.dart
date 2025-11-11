import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:appwizard/core/utils/multilocale_text_helper.dart';

void main() {
  group('MultilocaleTextHelper', () {
    late MultilocaleTextHelper helper;

    setUp(() {
      helper = const MultilocaleTextHelper();
    });

    Widget createTestWidget({
      required Locale locale,
      required Widget child,
    }) {
      return MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('es'),
        ],
        home: child,
      );
    }

    group('getText', () {
      testWidgets('should return string as-is when input is a string', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            locale: const Locale('en'),
            child: Builder(
              builder: (context) {
                final text = helper.getText(context, 'Simple text');
                return Text(text);
              },
            ),
          ),
        );

        expect(find.text('Simple text'), findsOneWidget);
      });

      testWidgets('should return empty string for null input', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            locale: const Locale('en'),
            child: Builder(
              builder: (context) {
                final text = helper.getText(context, null);
                return Text(text.isEmpty ? 'empty' : text);
              },
            ),
          ),
        );

        expect(find.text('empty'), findsOneWidget);
      });

      testWidgets('should extract English text for en locale', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            locale: const Locale('en'),
            child: Builder(
              builder: (context) {
                final text = helper.getText(context, {
                  'en': 'Hello',
                  'es': 'Hola',
                });
                return Text(text);
              },
            ),
          ),
        );

        expect(find.text('Hello'), findsOneWidget);
      });

      testWidgets('should extract Spanish text for es locale', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            locale: const Locale('es'),
            child: Builder(
              builder: (context) {
                final text = helper.getText(context, {
                  'en': 'Hello',
                  'es': 'Hola',
                });
                return Text(text);
              },
            ),
          ),
        );

        expect(find.text('Hola'), findsOneWidget);
      });

      testWidgets('should fallback to English when current locale not available', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            locale: const Locale('fr'), // French not in map
            child: Builder(
              builder: (context) {
                final text = helper.getText(context, {
                  'en': 'Hello',
                  'es': 'Hola',
                });
                return Text(text);
              },
            ),
          ),
        );

        expect(find.text('Hello'), findsOneWidget);
      });

      testWidgets('should fallback to first available value when en not available', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            locale: const Locale('fr'), // French not in map
            child: Builder(
              builder: (context) {
                final text = helper.getText(context, {
                  'es': 'Hola',
                  'de': 'Hallo',
                });
                return Text(text);
              },
            ),
          ),
        );

        // Should return first available value (order may vary, but should be one of them)
        expect(find.text('Hola'), findsOneWidget);
      });

      testWidgets('should handle map with non-string values gracefully', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            locale: const Locale('en'),
            child: Builder(
              builder: (context) {
                final text = helper.getText(context, {
                  'en': 123, // Not a string
                  'es': 'Hola',
                });
                // When 'en' is not a string, it falls back to first available value
                // If first value is also not a string, it uses toString()
                // The exact result depends on map iteration order
                return Text(text.isEmpty ? 'empty' : text);
              },
            ),
          ),
        );

        // Should return some non-empty value (either '123' or 'Hola' or toString of the map)
        expect(find.text('empty'), findsNothing);
      });

      testWidgets('should return toString for invalid input types', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            locale: const Locale('en'),
            child: Builder(
              builder: (context) {
                final text = helper.getText(context, 12345);
                return Text(text);
              },
            ),
          ),
        );

        expect(find.text('12345'), findsOneWidget);
      });
    });

    group('getLanguageCode', () {
      testWidgets('should return en for English locale', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            locale: const Locale('en'),
            child: Builder(
              builder: (context) {
                final code = helper.getLanguageCode(context);
                return Text(code);
              },
            ),
          ),
        );

        expect(find.text('en'), findsOneWidget);
      });

      testWidgets('should return es for Spanish locale', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            locale: const Locale('es'),
            child: Builder(
              builder: (context) {
                final code = helper.getLanguageCode(context);
                return Text(code);
              },
            ),
          ),
        );

        expect(find.text('es'), findsOneWidget);
      });
    });
  });
}

