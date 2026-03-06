import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/utils/text_highlight_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

/// Reusable widget for building styled descriptions with HTML, word highlighting, or plain text
/// Handles the common pattern of checking for HTML, then highlight words, then plain text
class StyledDescriptionWidget extends StatelessWidget {
  const StyledDescriptionWidget({
    super.key,
    required this.description,
    required this.highlightWordsData,
    required this.highlightColor,
    required this.textHighlightHelper,
    this.onRichTextDescription,
    this.padding,
    this.textAlign = TextAlign.center,
  });

  final String description;
  final dynamic highlightWordsData;
  final Color? highlightColor;
  final TextHighlightHelper textHighlightHelper;
  final EdgeInsets? padding;
  final TextAlign textAlign;
  final Widget Function(BuildContext, String, dynamic)? onRichTextDescription;

  @override
  Widget build(final BuildContext context) {
    // Check if description contains HTML tags
    final hasHtml = RegExp('<[^>]+>').hasMatch(description);

    // If HTML is present, use HTML parsing (takes precedence)
    if (hasHtml) {
      final htmlWidget = Html(
        data: description,
        style: {
          'body': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            textAlign: TextAlign.center,
            fontSize: FontSize(18),
            color: AppColors.backgroundDark.withValues(alpha: 0.9),
            lineHeight: const LineHeight(1.5),
          ),
          'span.highlight': Style(
            color: highlightColor,
            fontWeight: FontWeight.bold,
            fontSize: FontSize(20),
          ),
          'strong': Style(
            color: highlightColor,
            fontWeight: FontWeight.bold,
            fontSize: FontSize(20),
          ),
        },
      );

      if (padding != null) {
        return Padding(
          padding: padding!,
          child: htmlWidget,
        );
      }
      return htmlWidget;
    }

    // If highlight words are configured, use keyword-based highlighting
    if (highlightWordsData != null &&
        !(highlightWordsData is List && highlightWordsData.isEmpty) &&
        !(highlightWordsData is Map && highlightWordsData.isEmpty)) {
      if (onRichTextDescription != null) {
        final richTextWidget = onRichTextDescription!(
          context,
          description,
          highlightWordsData,
        );
        if (padding != null) {
          return Padding(
            padding: padding!,
            child: richTextWidget,
          );
        }
        return richTextWidget;
      }
    }

    // Plain text - render as regular text
    final textWidget = Text(
      description,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.backgroundDark.withValues(alpha: 0.9),
            height: 1.5,
            fontSize: 18,
          ),
      textAlign: textAlign,
    );

    if (padding != null) {
      return Padding(
        padding: padding!,
        child: textWidget,
      );
    }
    return textWidget;
  }
}

