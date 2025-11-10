import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_container.dart' as di;
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_helper.dart';
import '../../../core/widgets/visual_asset_widget.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../data/models/welcome_screen_config.dart';
import '../auth/sign_in_modal.dart';

/// Widget for the welcome/landing screen
/// Displays title, description, visual, and action buttons based on remote config
class WelcomeScreenWidget extends StatefulWidget {
  final WelcomeScreenConfig config;

  const WelcomeScreenWidget({
    super.key,
    required this.config,
  });

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
      backgroundColor: Colors.transparent, // Transparent to show global gradient
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
                color: AppColors.backgroundDark
                    .withValues(alpha: glassConfig.iconOpacity),
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
    final highlightWords = widget.config.highlightWords?.title ?? [];

    if (highlightWords.isEmpty) {
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

    // Rich text title with highlighted words
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: _buildRichTextTitle(context, widget.config.title, highlightWords),
    );
  }

  /// Build rich text title with highlighted words
  Widget _buildRichTextTitle(
    BuildContext context,
    String title,
    List<String> highlightWords,
  ) {
    final parts = title.split(' ');
    final textSpans = <TextSpan>[];

    for (int i = 0; i < parts.length; i++) {
      final word = parts[i];
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
      final isHighlight = highlightWords.any(
        (hw) =>
            cleanWord.contains(hw.toLowerCase()) ||
            hw.toLowerCase().contains(cleanWord),
      );

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
                      color: Colors.amber.withValues(alpha: 0.5),
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

  /// Build description with optional word highlighting
  Widget _buildDescription(BuildContext context) {
    final highlightWords = widget.config.highlightWords?.description ?? [];

    if (highlightWords.isEmpty) {
      // Simple description without highlighting
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          widget.config.description,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.backgroundDark.withValues(alpha: 0.9),
                height: 1.5,
                fontSize: 18,
              ),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Rich text description with highlighted words
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: _buildRichTextDescription(
        context,
        widget.config.description,
        highlightWords,
      ),
    );
  }

  /// Build rich text description with highlighted words
  Widget _buildRichTextDescription(
    BuildContext context,
    String description,
    List<String> highlightWords,
  ) {
    final parts = description.split(' ');
    final textSpans = <TextSpan>[];

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
                  color: Colors.amber,
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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
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
            style: TextStyle(
              color: AppColors.backgroundDark,
              fontSize: 14,
            ),
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

