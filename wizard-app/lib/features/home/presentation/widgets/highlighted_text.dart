import 'package:flutter/material.dart';

/// Text with remote-configured word highlights, e.g. `{"upgraded.": "#7B5EA7"}` or
/// `{"rewards": "bold"}`. Matching is case-insensitive and phrase-aware.
///
/// Also accepts the onboarding-style wrapper `{"title": {...}, "description": {...}}`
/// (pass [section] to pick the sub-map).
class HighlightedText extends StatelessWidget {
  const HighlightedText(
    this.text, {
    super.key,
    required this.style,
    this.highlights,
    this.section,
    this.defaultHighlightColor,
    this.textAlign = TextAlign.start,
    this.maxLines,
  });

  final String text;
  final TextStyle style;
  final dynamic highlights;
  final String? section;
  final Color? defaultHighlightColor;
  final TextAlign textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: buildSpans(text, style, highlights, section: section, fallback: defaultHighlightColor)),
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
      );

  /// Normalises the remote value to `word → color|"bold"`.
  static Map<String, String> normalize(dynamic highlights, {String? section}) {
    dynamic h = highlights;
    if (h is Map && section != null && h[section] is Map) h = h[section];
    if (h is Map && section == null && h['title'] is Map) h = h['title'];
    final out = <String, String>{};
    if (h is Map) {
      h.forEach((k, v) {
        final key = k.toString().trim();
        if (key.isNotEmpty && v != null) out[key] = v.toString().trim();
      });
    } else if (h is List) {
      for (final k in h) {
        final key = k.toString().trim();
        if (key.isNotEmpty) out[key] = 'bold';
      }
    }
    return out;
  }

  /// Splits [text] into spans, colouring / bolding the configured phrases.
  static List<InlineSpan> buildSpans(
    String text,
    TextStyle style,
    dynamic highlights, {
    String? section,
    Color? fallback,
  }) {
    final map = normalize(highlights, section: section);
    if (text.isEmpty || map.isEmpty) return [TextSpan(text: text, style: style)];

    final keys = map.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    final lower = text.toLowerCase();
    final spans = <InlineSpan>[];
    var cursor = 0;
    while (cursor < text.length) {
      var bestStart = -1;
      String? bestKey;
      for (final k in keys) {
        final i = lower.indexOf(k.toLowerCase(), cursor);
        if (i != -1 && (bestStart == -1 || i < bestStart)) {
          bestStart = i;
          bestKey = k;
        }
      }
      if (bestStart == -1 || bestKey == null) {
        spans.add(TextSpan(text: text.substring(cursor), style: style));
        break;
      }
      if (bestStart > cursor) spans.add(TextSpan(text: text.substring(cursor, bestStart), style: style));
      final end = bestStart + bestKey.length;
      spans.add(TextSpan(text: text.substring(bestStart, end), style: _styleFor(map[bestKey]!, style, fallback)));
      cursor = end;
    }
    return spans;
  }

  static TextStyle _styleFor(String value, TextStyle base, Color? fallback) {
    final v = value.toLowerCase();
    if (v == 'bold' || v == 'bold_large') {
      return base.copyWith(fontWeight: FontWeight.w700, color: fallback ?? base.color);
    }
    return base.copyWith(color: parseHexColor(value) ?? fallback ?? base.color);
  }

  /// `#RGB`, `#RRGGBB`, `#AARRGGBB` (with or without `#`, `0x` accepted).
  static Color? parseHexColor(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.startsWith('0x') || s.startsWith('0X')) s = s.substring(2);
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 3) s = s.split('').map((c) => '$c$c').join();
    if (s.length == 6) s = 'FF$s';
    if (s.length != 8) return null;
    final v = int.tryParse(s, radix: 16);
    return v == null ? null : Color(v);
  }
}
