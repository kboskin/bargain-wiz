import 'package:flutter/widgets.dart';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';

/// Fills `{placeholder}` tokens in remote-configured copy.
///
/// Example: `TemplateText.fill('Studying {platform} sellers…', {'platform': 'eBay'})`.
/// Unknown placeholders are left untouched so missing data is visible in QA.
class TemplateText {
  TemplateText._();

  static final RegExp _token = RegExp(r'\{([a-zA-Z0-9_]+)\}');

  static String fill(String template, Map<String, String?> values) {
    return template.replaceAllMapped(_token, (m) {
      final key = m.group(1)!;
      final v = values[key];
      return v ?? m.group(0)!;
    });
  }

  /// Resolves [source] (String or [MultilocaleText]) for the current locale, then fills placeholders.
  static String resolve(
    BuildContext context,
    dynamic source,
    Map<String, String?> values, {
    String fallback = '',
  }) {
    final raw = textOf(context, source, fallback: fallback);
    return fill(raw, values);
  }

  /// Returns the localized string for a remote-config value that may be a
  /// [MultilocaleText], a raw `String`, a `Map` or null.
  static String textOf(BuildContext context, dynamic source, {String fallback = ''}) {
    if (source == null) return fallback;
    if (source is MultilocaleText) {
      final s = source.get(context);
      return s.isEmpty ? fallback : s;
    }
    if (source is String) return source.isEmpty ? fallback : source;
    if (source is Map) {
      final s = MultilocaleText.fromJson(source).get(context);
      return s.isEmpty ? fallback : s;
    }
    return source.toString();
  }

  /// Highlight-words map may itself contain placeholders as keys (e.g. `{"{monthly_leak}": "#C47A00"}`).
  /// Returns a copy with keys filled so highlighting matches the rendered text.
  static Map<String, dynamic>? fillHighlightKeys(
    dynamic highlightWords,
    Map<String, String?> values,
  ) {
    if (highlightWords is! Map) return null;
    final out = <String, dynamic>{};
    highlightWords.forEach((k, v) {
      out[fill(k.toString(), values)] = v;
    });
    return out;
  }
}
