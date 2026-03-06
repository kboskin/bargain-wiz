import 'package:flutter/material.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/theme/app_colors.dart';
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
    this.highlightColor,
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
    final defaultHighlightColor = highlightColor;
    final config = textHighlightHelper.parseHighlightWords(highlightWordsData);
    final parts = description.split(' ');
    final textSpans = <TextSpan>[];
    final plainColor = baseColor.withValues(alpha: baseColorOpacity);

    for (final word in parts) {
      final result = textHighlightHelper.processWord(word, config, defaultHighlightColor);
      final useBold = result.isHighlight || result.isBold || result.isBoldLarge;
      final color = useBold
          ? (result.wordColor ?? defaultHighlightColor ?? baseColor)
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
