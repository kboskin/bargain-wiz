import 'package:flutter/material.dart';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/utils/color_helper.dart';
import 'package:appwizard/core/utils/text_highlight_helper.dart';
import 'package:appwizard/core/widgets/styled_description_widget.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';

/// Widget for engagement-type onboarding screens
/// Displays title, description, and optional Lottie animation
class EngagementScreenWidget extends StatefulWidget {
  final EngagementScreenModel model;

  const EngagementScreenWidget({
    super.key,
    required this.model,
  });

  @override
  State<EngagementScreenWidget> createState() => _EngagementScreenWidgetState();
}

class _EngagementScreenWidgetState extends State<EngagementScreenWidget> {
  late final ColorHelper _colorHelper;
  late final TextHighlightHelper _textHighlightHelper;

  @override
  void initState() {
    super.initState();
    _colorHelper = di.sl<ColorHelper>();
    _textHighlightHelper = TextHighlightHelper(_colorHelper);
  }

  @override
  Widget build(final BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Visual (Lottie or placeholder)
          // Size is configurable via metadata, defaults to 200x200
          if (widget.model.visual != null)
            _buildVisual(
              widget.model.visual!,
              width: _getVisualWidth(),
              height: _getVisualHeight(),
            )
          else
            _buildPlaceholderVisual(),
          const SizedBox(height: 48),

          // Title
          _buildStyledTitle(context, widget.model.title.get(context)),
          const SizedBox(height: 16),

          // Description (optional)
          if (widget.model.description != null) ...[
            Builder(
              builder: (context) {
                final descriptionText = widget.model.description!.get(context);
                if (descriptionText.isNotEmpty) {
                  return _buildStyledDescription(context, descriptionText);
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ],
      ),
    );

  /// Get visual width from metadata or default to 200
  double _getVisualWidth() {
    return widget.model.metadata?.width ?? 200.0;
  }

  /// Get visual height from metadata or default to 200
  double _getVisualHeight() {
    return widget.model.metadata?.height ?? 200.0;
  }

  Widget _buildVisual(String visualPath, {double width = 200, double height = 200}) {
    return VisualAssetWidget(
      visualPath: visualPath,
      width: width,
      height: height,
    );
  }
  
  /// Build placeholder visual
  Widget _buildPlaceholderVisual() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.check_circle_outline,
        color: AppColors.backgroundDark,
        size: 60,
      ),
    );
  }

  Widget _buildStyledTitle(BuildContext context, String title) {
    // Get highlight words from metadata (supports map or list format)
    final highlightWordsData = _getHighlightWords();

    if (highlightWordsData == null ||
        (highlightWordsData is List && highlightWordsData.isEmpty) ||
        (highlightWordsData is Map && highlightWordsData.isEmpty)) {
      // Simple title without highlighting
      return Text(
        title,
        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
          color: AppColors.backgroundDark,
          fontWeight: FontWeight.bold,
          fontSize: 32,
        ),
        textAlign: TextAlign.center,
      );
    }

    // Rich text title with highlighted words (supports per-word colors)
    return _buildRichTextTitle(context, title, highlightWordsData);
  }

  /// Build rich text title with highlighted words (same as welcome screen)
  /// Supports per-word colors via map: {"Bargain": "#FF6B35", "Wiz": "#4ECDC4"}
  /// Or simple list for backward compatibility: ["Bargain", "Wiz"]
  Widget _buildRichTextTitle(
    BuildContext context,
    String title,
    dynamic highlightWordsData,
  ) {
    final parts = title.split(' ');
    final textSpans = <TextSpan>[];
    final defaultHighlightColor = _getHighlightColor();

    // Parse highlight words using helper
    final config = _textHighlightHelper.parseHighlightWords(highlightWordsData);

    for (var i = 0; i < parts.length; i++) {
      final word = parts[i];
      final result = _textHighlightHelper.processWord(word, config, defaultHighlightColor);

      textSpans.add(
        TextSpan(
          text: i > 0 ? ' $word' : word,
          style: result.isHighlight
              ? TextStyle(
                  color: AppColors.backgroundDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 36,
                  shadows: [
                    Shadow(
                      color: result.wordColor?.withValues(alpha: 0.5) ?? Colors.transparent,
                      blurRadius: 20,
                      offset: const Offset(0, 0),
                    ),
                  ],
                )
              : Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppColors.backgroundDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                ),
        ),
      );
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: textSpans),
    );
  }

  /// Get highlight words from metadata
  dynamic _getHighlightWords() {
    return widget.model.metadata?.highlightWords?.title;
  }

  Widget _buildStyledDescription(BuildContext context, String description) {
    final highlightWordsData = _getDescriptionHighlightWords();
    final highlightColor = _getHighlightColor();

    return StyledDescriptionWidget(
      description: description,
      highlightWordsData: highlightWordsData,
      highlightColor: highlightColor,
      textHighlightHelper: _textHighlightHelper,
      onRichTextDescription: _buildRichTextDescription,
    );
  }

  /// Build rich text description with highlighted words.
  /// Supports isHighlight (color), isBold ("bold"), isBoldLarge ("bold_large").
  Widget _buildRichTextDescription(
    BuildContext context,
    String description,
    dynamic highlightWordsData,
  ) {
    final parts = description.split(' ');
    final textSpans = <TextSpan>[];
    final defaultHighlightColor = _getHighlightColor();
    const double bodySize = 18.0;
    const double boldLargeSize = 22.0;

    final config = _textHighlightHelper.parseHighlightWords(highlightWordsData);

    for (final word in parts) {
      final result = _textHighlightHelper.processWord(word, config, defaultHighlightColor);
      final useBold = result.isHighlight || result.isBold || result.isBoldLarge;
      final color = useBold
          ? (result.wordColor ?? defaultHighlightColor ?? AppColors.backgroundDark)
          : AppColors.backgroundDark.withValues(alpha: 0.9);
      final fontSize = result.isBoldLarge ? boldLargeSize : (result.isHighlight || result.isBold ? 20.0 : bodySize);

      textSpans.add(
        TextSpan(
          text: '$word ',
          style: useBold
              ? TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                  height: 1.5,
                )
              : Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: color,
                  height: 1.5,
                  fontSize: bodySize,
                ),
        ),
      );
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: textSpans),
    );
  }

  /// Get description highlight words from metadata
  dynamic _getDescriptionHighlightWords() {
    return widget.model.metadata?.highlightWords?.description;
  }

  /// Get highlight color from metadata
  /// Returns null if no valid color is found
  Color? _getHighlightColor() {
    final colorString = widget.model.metadata?.highlightColor;
    if (colorString != null && colorString.isNotEmpty) {
      return _colorHelper.getColor(colorString);
    }
    return null; // No color if not found
  }
}

