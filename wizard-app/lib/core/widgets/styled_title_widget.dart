import 'package:flutter/material.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/utils/color_helper.dart';
import 'package:appwizard/core/utils/text_highlight_helper.dart';

/// Reusable title widget with optional word highlighting (same pattern as onboarding).
/// Use [baseColor] for non-highlighted text (e.g. Colors.white for glass modals).
class StyledTitleWidget extends StatelessWidget {
  const StyledTitleWidget({
    super.key,
    required this.title,
    required this.baseColor,
    this.highlightWordsData,
    this.highlightColor,
    this.fontSize = 32.0,
    this.fontSizeHighlight = 36.0,
    this.fontWeight = FontWeight.w700,
  });

  final String title;
  final Color baseColor;
  final dynamic highlightWordsData;
  /// Hex string (e.g. "#4ECDC4") for default highlight color; parsed via [ColorHelper].
  final String? highlightColor;
  final double fontSize;
  final double fontSizeHighlight;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    final colorHelper = di.sl<ColorHelper>();
    final defaultHighlightColor = highlightColor != null && highlightColor!.isNotEmpty
        ? colorHelper.getColor(highlightColor!)
        : null;

    if (highlightWordsData == null ||
        (highlightWordsData is List && highlightWordsData.isEmpty) ||
        (highlightWordsData is Map && highlightWordsData.isEmpty)) {
      return Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: baseColor,
          fontWeight: fontWeight,
          fontSize: fontSize,
        ),
      );
    }

    final textHighlightHelper = TextHighlightHelper(colorHelper);
    final config = textHighlightHelper.parseHighlightWords(highlightWordsData);
    final textSpans = <TextSpan>[];
    final parts = title.split(' ');

    for (var i = 0; i < parts.length; i++) {
      final word = parts[i];
      final result = textHighlightHelper.processWord(word, config, defaultHighlightColor);
      final useBold = result.isHighlight || result.isBold || result.isBoldLarge;
      final color = useBold
          ? (result.wordColor ?? defaultHighlightColor ?? baseColor)
          : baseColor;
      textSpans.add(
        TextSpan(
          text: i > 0 ? ' $word' : word,
          style: useBold
              ? TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: fontSizeHighlight,
                  shadows: [
                    Shadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 0),
                    ),
                  ],
                )
              : TextStyle(
                  color: baseColor,
                  fontWeight: fontWeight,
                  fontSize: fontSize,
                ),
        ),
      );
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: textSpans),
    );
  }
}
