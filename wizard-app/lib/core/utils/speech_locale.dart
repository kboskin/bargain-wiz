import 'dart:ui' show Locale;

/// Picks the dictation locale for `SpeechToText.listen`.
///
/// Left to itself the plugin guesses, and the two platforms guess differently:
/// Android falls back to `Locale.getDefault()`, iOS to `Locale.current` — which
/// is the *formats* locale, so an English phone set to a Spanish region asks
/// `SFSpeechRecognizer` for `en_ES`, gets a null recognizer and fails the whole
/// session. Matching the device languages against the recognizer's own list
/// first means we only ever pass an id it actually knows.
///
/// [supported] are the `localeId`s from `SpeechToText.locales()` (Android spells
/// them `en_US`, iOS `en-US`); the winner is returned verbatim, in the plugin's
/// own spelling. [preferred] is the device language list, best first. Resolution
/// mirrors Flutter's own: language + country for every preferred locale, then
/// language alone. `null` means "nothing matched" — let the plugin decide.
String? resolveSpeechLocaleId({
  required List<String> supported,
  required List<Locale> preferred,
}) {
  if (supported.isEmpty || preferred.isEmpty) return null;

  for (final locale in preferred) {
    final country = locale.countryCode;
    if (country == null || country.isEmpty) continue;
    final target = '${locale.languageCode}-$country'.toLowerCase();
    for (final id in supported) {
      final parts = _parse(id);
      if (parts.length > 1 && '${parts.first}-${parts.last}' == target) return id;
    }
  }

  for (final locale in preferred) {
    final language = locale.languageCode.toLowerCase();
    for (final id in supported) {
      if (_parse(id).first == language) return id;
    }
  }

  return null;
}

/// `en_US`, `en-US`, `zh-Hans-CN` or `en_US@rg=eszzzz` → `[en, …, us]`.
List<String> _parse(String localeId) =>
    localeId.split('@').first.toLowerCase().split(RegExp('[-_]'));
