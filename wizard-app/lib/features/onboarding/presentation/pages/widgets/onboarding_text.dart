import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:flutter/material.dart';

/// Rich text with remote-configured phrase highlights.
///
/// [highlights] is either a `Map<String, String>` (`phrase → "#RRGGBB" | "bold" | "bold_large"`)
/// or a `List<String>` of phrases (coloured with [defaultHighlightColor]). Phrases may span
/// several words and are matched case-insensitively; keys in other locales simply don't match.
class HighlightedText extends StatelessWidget {
  const HighlightedText(
    this.text, {
    required this.style,
    super.key,
    this.highlights,
    this.defaultHighlightColor,
    this.highlightWeight,
    this.boldColor = WizColors.ink,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle style;
  final dynamic highlights;
  /// Colour for list-style highlights and for map values that aren't a valid colour.
  final Color? defaultHighlightColor;
  /// Weight applied to coloured highlights; null keeps the base weight (titles).
  final FontWeight? highlightWeight;
  /// Colour for `"bold"` highlights (ink by default).
  final Color boldColor;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(
          children: spans(
            text,
            style: style,
            highlights: highlights,
            defaultHighlightColor: defaultHighlightColor,
            highlightWeight: highlightWeight,
            boldColor: boldColor,
          ),
        ),
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );

  /// Builds the spans; exposed so callers can embed them in other rich text.
  static List<InlineSpan> spans(
    String text, {
    required TextStyle style,
    dynamic highlights,
    Color? defaultHighlightColor,
    FontWeight? highlightWeight,
    Color boldColor = WizColors.ink,
  }) {
    final rules = _rules(highlights, defaultHighlightColor);
    if (rules.isEmpty || text.isEmpty) return [TextSpan(text: text, style: style)];

    final lower = text.toLowerCase();
    final matches = <_Match>[];
    for (final rule in rules) {
      final needle = rule.phrase.toLowerCase();
      if (needle.isEmpty) continue;
      var from = 0;
      while (true) {
        final i = lower.indexOf(needle, from);
        if (i < 0) break;
        matches.add(_Match(i, i + needle.length, rule));
        from = i + needle.length;
      }
    }
    if (matches.isEmpty) return [TextSpan(text: text, style: style)];

    // Earliest start wins; on ties prefer the longer phrase. Drop overlaps.
    matches.sort((a, b) => a.start != b.start ? a.start.compareTo(b.start) : b.end.compareTo(a.end));
    final out = <InlineSpan>[];
    var cursor = 0;
    for (final m in matches) {
      if (m.start < cursor) continue;
      if (m.start > cursor) out.add(TextSpan(text: text.substring(cursor, m.start), style: style));
      out.add(TextSpan(text: text.substring(m.start, m.end), style: m.rule.apply(style, highlightWeight, boldColor)));
      cursor = m.end;
    }
    if (cursor < text.length) out.add(TextSpan(text: text.substring(cursor), style: style));
    return out;
  }

  static List<_Rule> _rules(dynamic highlights, Color? fallback) {
    if (highlights is Map) {
      return [
        for (final e in highlights.entries)
          _Rule(e.key.toString(), _kind(e.value), _color(e.value) ?? fallback),
      ];
    }
    if (highlights is List) {
      return [for (final p in highlights) _Rule(p.toString(), _Kind.color, fallback)];
    }
    return const [];
  }

  static _Kind _kind(dynamic v) {
    final s = v?.toString().trim().toLowerCase();
    if (s == 'bold') return _Kind.bold;
    if (s == 'bold_large') return _Kind.boldLarge;
    return _Kind.color;
  }

  static Color? _color(dynamic v) {
    if (v is! String) return null;
    var h = v.replaceFirst('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    final n = int.tryParse(h, radix: 16);
    return n == null ? null : Color(n);
  }
}

enum _Kind { color, bold, boldLarge }

class _Rule {
  const _Rule(this.phrase, this.kind, this.color);
  final String phrase;
  final _Kind kind;
  final Color? color;

  TextStyle apply(TextStyle base, FontWeight? highlightWeight, Color boldColor) {
    switch (kind) {
      case _Kind.bold:
        return base.copyWith(fontWeight: FontWeight.w700, color: boldColor);
      case _Kind.boldLarge:
        return base.copyWith(
          fontWeight: FontWeight.w700,
          color: boldColor,
          fontSize: (base.fontSize ?? 16) + 2,
        );
      case _Kind.color:
        return base.copyWith(
          color: color ?? base.color,
          fontWeight: highlightWeight ?? base.fontWeight,
        );
    }
  }
}

class _Match {
  const _Match(this.start, this.end, this.rule);
  final int start;
  final int end;
  final _Rule rule;
}

/// Title (Outfit 28/700 at margin-top 26) + optional description (Figtree 15) for
/// content-type onboarding screens, with per-screen `highlight_words` and
/// optional `{placeholder}` filling.
class OnboardingScreenHeader extends StatelessWidget {
  const OnboardingScreenHeader({
    required this.model,
    super.key,
    this.textColor = WizColors.ink,
    this.titleStyle,
    this.descriptionStyle,
    this.placeholders,
    this.titleHighlightWeight,
    this.topGap = 26,
    this.descriptionGap = 6,
    this.bottomGap = 16,
    this.textAlign = TextAlign.start,
  });

  final OnboardingModel model;
  final Color textColor;
  final TextStyle? titleStyle;
  final TextStyle? descriptionStyle;
  /// `{placeholder}` values filled into title, description and highlight keys.
  final Map<String, String?>? placeholders;
  final FontWeight? titleHighlightWeight;
  final double topGap;
  final double descriptionGap;
  final double bottomGap;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final values = placeholders ?? const <String, String?>{};
    final title = TemplateText.resolve(context, model.title, values);
    final description = TemplateText.resolve(context, model.description, values);
    final highlightColor = HighlightedText._color(model.effectiveHighlightColor);

    return Column(
      crossAxisAlignment: textAlign == TextAlign.center ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: topGap),
        HighlightedText(
          title,
          style: (titleStyle ?? WizType.title).copyWith(color: textColor),
          highlights: TemplateText.fillHighlightKeys(model.titleHighlights, values) ?? model.titleHighlights,
          defaultHighlightColor: highlightColor,
          highlightWeight: titleHighlightWeight,
          boldColor: textColor,
          textAlign: textAlign,
        ),
        if (description.isNotEmpty) ...[
          SizedBox(height: descriptionGap),
          HighlightedText(
            description,
            style: descriptionStyle ?? WizType.bodyMd,
            highlights:
                TemplateText.fillHighlightKeys(model.descriptionHighlights, values) ?? model.descriptionHighlights,
            defaultHighlightColor: highlightColor,
            highlightWeight: FontWeight.w600,
            boldColor: textColor,
            textAlign: textAlign,
          ),
        ],
        SizedBox(height: bottomGap),
      ],
    );
  }
}

/// Column that fills the available height (so `Expanded` children work) but
/// scrolls when the content is taller than the viewport (long Spanish copy).
class OnboardingScrollFill extends StatelessWidget {
  const OnboardingScrollFill({required this.children, super.key, this.crossAxisAlignment = CrossAxisAlignment.stretch});

  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          clipBehavior: Clip.none,
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(crossAxisAlignment: crossAxisAlignment, children: children),
            ),
          ),
        ),
      );
}

/// White check mark used by option cards / checkboxes.
class WizCheckMark extends StatelessWidget {
  const WizCheckMark({super.key, this.size = 14, this.color = Colors.white});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Icon(Icons.check_rounded, size: size, color: color);
}

/// Parses a remote hex colour ("#RRGGBB" / "#AARRGGBB"); null when invalid.
Color? wizHexColor(String? hex) => HighlightedText._color(hex);
