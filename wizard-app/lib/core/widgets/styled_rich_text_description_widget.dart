import 'package:flutter/material.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/utils/color_helper.dart';
import 'package:appwizard/core/utils/text_highlight_helper.dart';

/// Reusable rich text description with word highlighting (same pattern as onboarding).
/// Use with [StyledDescriptionWidget] as [onRichTextDescription] or standalone.
class StyledRichTextDescriptionWidget extends StatelessWidget {
  const StyledRichTextDescriptionWidget({
    super.key,
    required this.description,
    required this.highlightWordsData,
    required this.baseColor,
    this.baseColorHex,
    this.highlightColor,
    this.highlightColorHex,
    this.textAlign = TextAlign.center,
    this.bodyFontSize = 18.0,
    this.boldFontSize = 20.0,
    this.boldLargeFontSize = 22.0,
    this.baseColorOpacity = 0.9,
    this.height = 1.5,
  });

  final String description;
  final dynamic highlightWordsData;
  final Color baseColor;
  final Color? highlightColor;
  /// Optional hex string for base text color (e.g. "#FFFFFF"). When provided,
  /// this overrides [baseColor] after being resolved via [ColorHelper].
  final String? baseColorHex;
  /// Optional hex string for default highlight color (e.g. "#4ECDC4"). When
  /// provided, this is resolved via [ColorHelper] and used when words don't
  /// specify their own color.
  final String? highlightColorHex;
  final TextAlign textAlign;
  final double bodyFontSize;
  final double boldFontSize;
  final double boldLargeFontSize;
  final double baseColorOpacity;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorHelper = di.sl<ColorHelper>();
    final textHighlightHelper = TextHighlightHelper(colorHelper);
    // Resolve base color: allow either direct Color or hex string override.
    final effectiveBaseColor = (baseColorHex != null && baseColorHex!.isNotEmpty)
        ? (colorHelper.getColor(baseColorHex!) ?? baseColor)
        : baseColor;
    // Resolve default highlight color: prefer explicit Color, then hex string.
    final resolvedHighlightFromHex = (highlightColorHex != null && highlightColorHex!.isNotEmpty)
        ? colorHelper.getColor(highlightColorHex!)
        : null;
    final defaultHighlightColor = highlightColor ?? resolvedHighlightFromHex;
    final config = textHighlightHelper.parseHighlightWords(highlightWordsData);
    final parts = description.split(' ');
    final textSpans = <TextSpan>[];
    final plainColor = effectiveBaseColor.withValues(alpha: baseColorOpacity);

    for (final word in parts) {
      final result = textHighlightHelper.processWord(word, config, defaultHighlightColor);
      final useBold = result.isHighlight || result.isBold || result.isBoldLarge;
      final color = useBold
          ? (result.wordColor ?? defaultHighlightColor ?? effectiveBaseColor)
          : plainColor;
      final fontSize = result.isBoldLarge
          ? boldLargeFontSize
          : (result.isHighlight || result.isBold ? boldFontSize : bodyFontSize);
      textSpans.add(
        TextSpan(
          text: '$word ',
          style: useBold
              ? TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                  height: height,
                )
              : TextStyle(
                  color: color,
                  fontSize: bodyFontSize,
                  height: height,
                ),
        ),
      );
    }

    return RichText(
      textAlign: textAlign,
      text: TextSpan(children: textSpans),
    );
  }
}
