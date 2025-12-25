import 'package:flutter/material.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_helper.dart';
import '../../../../core/utils/multilocale_text_helper.dart';
import '../../../../core/utils/text_highlight_helper.dart';
import '../../../../core/widgets/styled_description_widget.dart';
import '../../../../core/widgets/visual_asset_widget.dart';
import '../../../../data/models/remote_config/onboarding_model.dart';

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
  ColorHelper? _cachedColorHelper;
  MultilocaleTextHelper? _cachedMultilocaleTextHelper;
  TextHighlightHelper? _cachedTextHighlightHelper;

  @override
  Widget build(BuildContext context) {
    // Cache ColorHelper lookup
    _cachedColorHelper ??= di.sl<ColorHelper>();
    _cachedMultilocaleTextHelper ??= di.sl<MultilocaleTextHelper>();
    _cachedTextHighlightHelper ??= TextHighlightHelper(_cachedColorHelper!);
    return Padding(
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
          _buildStyledTitle(context, _cachedMultilocaleTextHelper!.getText(context, widget.model.title)),
          const SizedBox(height: 16),

          // Description (optional)
          if (widget.model.description != null) ...[
            Builder(
              builder: (context) {
                final descriptionText = _cachedMultilocaleTextHelper!.getText(context, widget.model.description);
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
  }

  /// Get visual width from metadata or default to 200
  double _getVisualWidth() {
    if (widget.model.metadata != null && widget.model.metadata!.containsKey('width')) {
      final width = widget.model.metadata!['width'];
      if (width is num) {
        return width.toDouble();
      }
    }
    return 200.0; // Default width
  }

  /// Get visual height from metadata or default to 200
  double _getVisualHeight() {
    if (widget.model.metadata != null && widget.model.metadata!.containsKey('height')) {
      final height = widget.model.metadata!['height'];
      if (height is num) {
        return height.toDouble();
      }
    }
    return 200.0; // Default height
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
    final config = _cachedTextHighlightHelper!.parseHighlightWords(highlightWordsData);

    for (var i = 0; i < parts.length; i++) {
      final word = parts[i];
      final result = _cachedTextHighlightHelper!.processWord(word, config, defaultHighlightColor);

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

  /// Get highlight words from metadata (supports map or list format)
  dynamic _getHighlightWords() {
    if (widget.model.metadata != null && widget.model.metadata!.containsKey('highlight_words')) {
      final highlightWordsData = widget.model.metadata!['highlight_words'];
      if (highlightWordsData is Map<String, dynamic> && highlightWordsData.containsKey('title')) {
        return highlightWordsData['title'];
      }
    }
    return null;
  }

  Widget _buildStyledDescription(BuildContext context, String description) {
    final highlightWordsData = _getDescriptionHighlightWords();
    final highlightColor = _getHighlightColor();

    return StyledDescriptionWidget(
      description: description,
      highlightWordsData: highlightWordsData,
      highlightColor: highlightColor,
      textHighlightHelper: _cachedTextHighlightHelper!,
      onRichTextDescription: _buildRichTextDescription,
    );
  }

  /// Build rich text description with highlighted words (same as welcome screen)
  /// Supports per-word colors via map: {"the": "#FF6B35", "best": "#4ECDC4", "deal": "#FF6B35"}
  /// Or simple list for backward compatibility: ["the", "best", "deal"]
  Widget _buildRichTextDescription(
    BuildContext context,
    String description,
    dynamic highlightWordsData,
  ) {
    final parts = description.split(' ');
    final textSpans = <TextSpan>[];
    final defaultHighlightColor = _getHighlightColor();

    // Parse highlight words using helper
    final config = _cachedTextHighlightHelper!.parseHighlightWords(highlightWordsData);

    for (final word in parts) {
      final result = _cachedTextHighlightHelper!.processWord(word, config, defaultHighlightColor);

      textSpans.add(
        TextSpan(
          text: '$word ',
          style: result.isHighlight
              ? TextStyle(
                  color: result.wordColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                )
              : Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.backgroundDark.withValues(alpha: 0.9),
                  height: 1.5,
                  fontSize: 18,
                ),
        ),
      );
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: textSpans),
    );
  }

  /// Get description highlight words from metadata (supports map or list format)
  dynamic _getDescriptionHighlightWords() {
    if (widget.model.metadata != null && widget.model.metadata!.containsKey('highlight_words')) {
      final highlightWordsData = widget.model.metadata!['highlight_words'];
      if (highlightWordsData is Map<String, dynamic> && highlightWordsData.containsKey('description')) {
        return highlightWordsData['description'];
      }
    }
    return null;
  }

  /// Get highlight color from metadata
  /// Returns null if no valid color is found
  Color? _getHighlightColor() {
    if (widget.model.metadata != null && widget.model.metadata!.containsKey('highlight_color')) {
      final colorString = widget.model.metadata!['highlight_color'] as String?;
      if (colorString != null && colorString.isNotEmpty) {
        return _cachedColorHelper!.getColor(colorString);
      }
    }
    return null; // No color if not found
  }
}

