import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection_container.dart' as di;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/color_helper.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/visual_asset_widget.dart';
import '../../../data/models/welcome_screen_config.dart';
import '../auth/sign_in_modal.dart';

/// Widget for the welcome/landing screen
/// Displays title, description, visual, and action buttons based on remote config
class WelcomeScreenWidget extends StatefulWidget {
  final WelcomeScreenConfig config;

  const WelcomeScreenWidget({super.key, required this.config});

  @override
  State<WelcomeScreenWidget> createState() => _WelcomeScreenWidgetState();
}

class _WelcomeScreenWidgetState extends State<WelcomeScreenWidget> {
  ColorHelper? _cachedColorHelper;

  @override
  Widget build(BuildContext context) {
    // Cache ColorHelper lookup
    _cachedColorHelper ??= di.sl<ColorHelper>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      // Transparent to show global gradient
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // Visual (Lottie, image, or glass container placeholder)
            _buildVisual(),
            const SizedBox(height: 40),
            // Title with optional highlighting
            _buildTitle(context),
            const SizedBox(height: 16),
            // Description with optional highlighting
            _buildDescription(context),
            const SizedBox(height: 40),
            // Primary action button
            _buildPrimaryButton(context),
            const SizedBox(height: 16),
            // Secondary action (e.g., Sign in link)
            if (widget.config.secondaryAction != null) ...[
              _buildSecondaryAction(context),
            ],
            const Spacer(),
          ],
        ),
      ),
    );
  }

  /// Build visual element (Lottie/image or glass container placeholder)
  Widget _buildVisual() {
    if (widget.config.visual != null) {
      // Use VisualAssetWidget for Lottie/images
      return VisualAssetWidget(
        visualPath: widget.config.visual!,
        width: 200,
        height: 200,
      );
    }

    // Use glass container placeholder if no visual specified
    if (widget.config.glassContainer != null) {
      final glassConfig = widget.config.glassContainer!;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: GlassContainer(
          blurSigma: glassConfig.blurSigma,
          color: _cachedColorHelper!.getColor(
            glassConfig.color,
            defaultColor: Colors.white,
          ),
          opacity: glassConfig.opacity,
          borderRadius: BorderRadius.circular(glassConfig.borderRadius),
          child: SizedBox(
            height: glassConfig.height,
            child: Center(
              child: Icon(
                Icons.shopping_bag,
                size: glassConfig.iconSize,
                color: AppColors.backgroundDark.withValues(
                  alpha: glassConfig.iconOpacity,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Default placeholder
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

  /// Build title with optional word highlighting
  Widget _buildTitle(BuildContext context) {
    final highlightWordsData = widget.config.highlightWords?.title;

    if (highlightWordsData == null || 
        (highlightWordsData is List && highlightWordsData.isEmpty) ||
        (highlightWordsData is Map && highlightWordsData.isEmpty)) {
      // Simple title without highlighting
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          widget.config.title,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: AppColors.backgroundDark,
            fontWeight: FontWeight.bold,
            fontSize: 32,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Rich text title with highlighted words (supports per-word colors)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: _buildRichTextTitle(context, widget.config.title, highlightWordsData),
    );
  }

  /// Build rich text title with highlighted words
  /// Supports per-word colors via map: {"Bargain": "#FF6B35", "Wiz": "#4ECDC4"}
  /// Or simple list for backward compatibility: ["best", "deals"]
  Widget _buildRichTextTitle(
    BuildContext context,
    String title,
    dynamic highlightWordsData,
  ) {
    final parts = title.split(' ');
    final textSpans = <TextSpan>[];
    final defaultHighlightColor = _getHighlightColor();

    // Parse highlight words - can be a map (word -> color) or list (backward compatibility)
    Map<String, Color> wordColors = {};
    List<String> highlightWords = [];
    
    if (highlightWordsData is Map) {
      // Map format: {"Bargain": "#FF6B35", "Wiz": "#4ECDC4"}
      highlightWordsData.forEach((word, colorValue) {
        final wordStr = word.toString();
        highlightWords.add(wordStr);
        if (colorValue is String) {
          wordColors[wordStr.toLowerCase()] = _cachedColorHelper!.getColor(
            colorValue,
            defaultColor: defaultHighlightColor,
          );
        }
      });
    } else if (highlightWordsData is List) {
      // List format: ["best", "deals"] - backward compatibility
      highlightWords = highlightWordsData.map((item) => item.toString()).toList();
    }

    for (int i = 0; i < parts.length; i++) {
      final word = parts[i];
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
      
      // Find matching highlight word
      String? matchedWord;
      for (final hw in highlightWords) {
        final cleanHw = hw.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
        if (cleanWord.contains(cleanHw) || cleanHw.contains(cleanWord)) {
          matchedWord = hw;
          break;
        }
      }

      final isHighlight = matchedWord != null;
      final wordColor = isHighlight && wordColors.containsKey(matchedWord!.toLowerCase())
          ? wordColors[matchedWord.toLowerCase()]!
          : defaultHighlightColor;

      textSpans.add(
        TextSpan(
          text: i > 0 ? ' $word' : word,
          style: isHighlight
              ? TextStyle(
                  color: AppColors.backgroundDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 36,
                  shadows: [
                    Shadow(
                      color: wordColor.withValues(alpha: 0.5),
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

  /// Build description with optional HTML or word highlighting
  Widget _buildDescription(BuildContext context) {
    final description = widget.config.description;
    final hasHtml = RegExp(r'<[^>]+>').hasMatch(description);
    final highlightWords = widget.config.highlightWords?.description ?? [];
    final highlightColor = _getHighlightColor();

    // If HTML is present, use HTML parsing (takes precedence)
    if (hasHtml) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Html(
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
        ),
      );
    }

    // If highlight words are configured, use keyword-based highlighting
    if (highlightWords.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: _buildRichTextDescription(context, description, highlightWords),
      );
    }

    // Simple description without highlighting
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Text(
        description,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: AppColors.backgroundDark.withValues(alpha: 0.9),
          height: 1.5,
          fontSize: 18,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Build rich text description with highlighted words (fallback for non-HTML)
  Widget _buildRichTextDescription(
    BuildContext context,
    String description,
    List<String> highlightWords,
  ) {
    final parts = description.split(' ');
    final textSpans = <TextSpan>[];
    final highlightColor = _getHighlightColor();

    for (final word in parts) {
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
      final isHighlight = highlightWords.any(
        (hw) =>
            cleanWord.contains(hw.toLowerCase()) ||
            hw.toLowerCase().contains(cleanWord),
      );

      textSpans.add(
        TextSpan(
          text: '$word ',
          style: isHighlight
              ? TextStyle(
                  color: highlightColor,
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

  /// Get highlight color from config or default to amber
  Color _getHighlightColor() {
    if (widget.config.highlightColor != null) {
      return _cachedColorHelper!.getColor(
        widget.config.highlightColor!,
        defaultColor: Colors.amber,
      );
    }
    return Colors.amber; // Default color
  }

  /// Build primary action button
  Widget _buildPrimaryButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            // Navigate to onboarding flow
            context.push('/onboarding');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.backgroundDark,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            widget.config.primaryButtonText,
            style: AppTextStyles.buttonText,
          ),
        ),
      ),
    );
  }

  /// Build secondary action (e.g., Sign in link)
  Widget _buildSecondaryAction(BuildContext context) {
    final action = widget.config.secondaryAction!;

    if (action.type == 'sign_in') {
      return TextButton(
        onPressed: () => _showSignInModal(context),
        child: RichText(
          text: TextSpan(
            style: TextStyle(color: AppColors.backgroundDark, fontSize: 14),
            children: [
              TextSpan(text: action.prefixText),
              TextSpan(
                text: action.text,
                style: TextStyle(
                  color: AppColors.backgroundDark,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.backgroundDark,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _showSignInModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const SignInModal(),
    );
  }
}
