import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/theme/app_text_styles.dart';
import 'package:appwizard/core/utils/color_helper.dart';
import 'package:appwizard/core/utils/multilocale_text_helper.dart';
import 'package:appwizard/core/utils/text_highlight_helper.dart';
import 'package:appwizard/core/widgets/styled_description_widget.dart';
import 'package:appwizard/core/widgets/glass_container.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/data/models/remote_config/welcome_screen_config.dart';
import 'package:appwizard/presentation/pages/auth/sign_in_modal.dart';

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
  MultilocaleTextHelper? _cachedMultilocaleTextHelper;
  TextHighlightHelper? _cachedTextHighlightHelper;

  @override
  Widget build(BuildContext context) {
    // Cache ColorHelper lookup
    _cachedColorHelper ??= di.sl<ColorHelper>();
    _cachedMultilocaleTextHelper ??= di.sl<MultilocaleTextHelper>();
    _cachedTextHighlightHelper ??= TextHighlightHelper(_cachedColorHelper!);

    return Scaffold(
      backgroundColor: Colors.transparent,
      // Transparent to show global gradient
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const Spacer(flex: 1),
                      // Visual (Lottie, image, or glass container placeholder)
                      _buildVisual(),
                      const SizedBox(height: 32),
                      // Title with optional highlighting
                      _buildTitle(context),
                      const SizedBox(height: 12),
                      // Description with optional highlighting
                      _buildDescription(context),
                      const SizedBox(height: 32),
                      // Primary action button
                      _buildPrimaryButton(context),
                      const SizedBox(height: 12),
                      // Secondary action (e.g., Sign in link)
                      if (widget.config.secondaryAction != null) ...[
                        _buildSecondaryAction(context),
                      ],
                      // Add bottom padding to prevent overflow
                      SizedBox(height: MediaQuery.of(context).padding.bottom),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Build visual element (Lottie/image or glass container placeholder)
  Widget _buildVisual() {
    if (widget.config.visual != null) {
      // Use VisualAssetWidget for Lottie/images (reduced size for better visibility of terms)
      return VisualAssetWidget(
        visualPath: widget.config.visual!,
        width: 160,
        height: 160,
      );
    }

    // Use glass container placeholder if no visual specified
    if (widget.config.glassContainer != null) {
      final glassConfig = widget.config.glassContainer!;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: GlassContainer(
          blurSigma: glassConfig.blurSigma,
          color: _cachedColorHelper!.getColor(glassConfig.color) ?? Colors.white,
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
    final titleText = _cachedMultilocaleTextHelper!.getText(context, widget.config.title);
    final highlightWordsData = widget.config.highlightWords?.title;

    if (highlightWordsData == null || 
        (highlightWordsData is List && highlightWordsData.isEmpty) ||
        (highlightWordsData is Map && highlightWordsData.isEmpty)) {
      // Simple title without highlighting
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          titleText,
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
      child: _buildRichTextTitle(context, titleText, highlightWordsData),
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

    // Parse highlight words using helper
    final config = _cachedTextHighlightHelper!.parseHighlightWords(highlightWordsData);

    for (int i = 0; i < parts.length; i++) {
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

  /// Build description with optional HTML or word highlighting
  Widget _buildDescription(BuildContext context) {
    final description = _cachedMultilocaleTextHelper!.getText(context, widget.config.description);
    final highlightWordsData = widget.config.highlightWords?.description;
    final highlightColor = _getHighlightColor();

    return StyledDescriptionWidget(
      description: description,
      highlightWordsData: highlightWordsData,
      highlightColor: highlightColor,
      textHighlightHelper: _cachedTextHighlightHelper!,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      onRichTextDescription: _buildRichTextDescription,
    );
  }

  /// Build rich text description with highlighted words (fallback for non-HTML)
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

  /// Get highlight color from config
  /// Returns null if no valid color is found
  Color? _getHighlightColor() {
    if (widget.config.highlightColor != null) {
      return _cachedColorHelper!.getColor(widget.config.highlightColor!);
    }
    return null; // No color if not found
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
            _cachedMultilocaleTextHelper!.getText(context, widget.config.primaryButtonText),
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
              TextSpan(text: _cachedMultilocaleTextHelper!.getText(context, action.prefixText)),
              TextSpan(
                text: _cachedMultilocaleTextHelper!.getText(context, action.text),
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
