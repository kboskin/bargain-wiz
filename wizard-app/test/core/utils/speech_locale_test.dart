import 'dart:ui' show Locale;

import 'package:appwizard/core/utils/speech_locale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveSpeechLocaleId', () {
    // Android spelling; iOS hands back the same ids with hyphens.
    const android = ['en_US', 'en_GB', 'es_ES', 'es_MX', 'uk_UA'];
    const ios = ['en-US', 'en-GB', 'es-ES', 'es-MX', 'uk-UA'];

    test('matches language and country', () {
      expect(
        resolveSpeechLocaleId(supported: android, preferred: [const Locale('en', 'GB')]),
        'en_GB',
      );
      expect(
        resolveSpeechLocaleId(supported: ios, preferred: [const Locale('es', 'MX')]),
        'es-MX',
      );
    });

    test('falls back to the language when the country is unsupported', () {
      expect(
        resolveSpeechLocaleId(supported: android, preferred: [const Locale('es', 'AR')]),
        'es_ES',
      );
      expect(
        resolveSpeechLocaleId(supported: android, preferred: [const Locale('en')]),
        'en_US',
      );
    });

    test('prefers an exact match further down the list over a language-only one', () {
      expect(
        resolveSpeechLocaleId(
          supported: android,
          preferred: [const Locale('en', 'IN'), const Locale('uk', 'UA')],
        ),
        'uk_UA',
      );
    });

    test('ignores region-only and script subtags in the recognizer ids', () {
      expect(
        resolveSpeechLocaleId(
          supported: const ['en_US@rg=eszzzz', 'zh-Hans-CN'],
          preferred: [const Locale('zh', 'CN')],
        ),
        'zh-Hans-CN',
      );
    });

    test('returns null when nothing matches, leaving the plugin its default', () {
      expect(
        resolveSpeechLocaleId(supported: android, preferred: [const Locale('ja', 'JP')]),
        isNull,
      );
      expect(
        resolveSpeechLocaleId(supported: const [], preferred: [const Locale('en', 'US')]),
        isNull,
      );
      expect(resolveSpeechLocaleId(supported: android, preferred: const []), isNull);
    });
  });
}
