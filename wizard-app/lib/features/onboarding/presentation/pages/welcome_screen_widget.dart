import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/theme/app_text_styles.dart';
import 'package:appwizard/core/utils/color_helper.dart';
import 'package:appwizard/core/utils/text_highlight_helper.dart';
import 'package:appwizard/core/widgets/styled_description_widget.dart';
import 'package:appwizard/core/widgets/styled_rich_text_description_widget.dart';
import 'package:appwizard/core/widgets/styled_title_widget.dart';
import 'package:appwizard/core/widgets/glass_container.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/welcome_screen_config.dart';
import 'package:appwizard/features/auth/presentation/pages/sign_in_modal.dart';
import 'package:appwizard/core/routing/app_routes.dart';

/// Widget for the welcome/landing screen
/// Displays title, description, visual, and action buttons based on remote config
class WelcomeScreenWidget extends StatefulWidget {
  final WelcomeScreenConfig config;

  const WelcomeScreenWidget({super.key, required this.config});

  @override
  State<WelcomeScreenWidget> createState() => _WelcomeScreenWidgetState();
}

class _WelcomeScreenWidgetState extends State<WelcomeScreenWidget> {
  late final ColorHelper _colorHelper;
  late final TextHighlightHelper _textHighlightHelper;

  @override
  void initState() {
    super.initState();
    _colorHelper = di.sl<ColorHelper>();
    _textHighlightHelper = TextHighlightHelper(_colorHelper);
  }

  @override
  Widget build(final BuildContext context) => Scaffold(
      backgroundColor: Colors.transparent,
      // Transparent to show global gradient
      body: SafeArea(
        child: LayoutBuilder(
          builder: (final context, final constraints) => SingleChildScrollView(
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: StyledTitleWidget(
                          title: widget.config.title.get(context),
                          baseColor: _getTextColor(),
                          highlightWordsData: widget.config.highlightWords?.title,
                          highlightColor: widget.config.highlightColor,
                        ),
                      ),
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
            ),
        ),
      ),
    );

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
          color: _colorHelper.getColor(glassConfig.color) ?? Colors.white,
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
      decoration: const BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.check_circle_outline,
        color: AppColors.backgroundDark,
        size: 60,
      ),
    );
  }

  /// Build description with optional HTML or word highlighting
  Widget _buildDescription(BuildContext context) {
    final description = widget.config.description.get(context);
    final highlightWordsData = widget.config.highlightWords?.description;
    final highlightColor = _getHighlightColor();

    return StyledDescriptionWidget(
      description: description,
      highlightWordsData: highlightWordsData,
      highlightColor: highlightColor,
      textHighlightHelper: _textHighlightHelper,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      onRichTextDescription: (ctx, desc, data) => StyledRichTextDescriptionWidget(
        description: desc,
        highlightWordsData: data,
        baseColor: _getTextColor(),
        highlightColor: _getHighlightColor(),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Base text color from config (title/description). Defaults to black when null or invalid.
  Color _getTextColor() {
    final hex = widget.config.textColor;
    if (hex != null && hex.isNotEmpty) {
      return _colorHelper.getColor(hex) ?? AppColors.backgroundDark;
    }
    return AppColors.backgroundDark;
  }

  /// Get highlight color from config
  /// Returns null if no valid color is found
  Color? _getHighlightColor() {
    if (widget.config.highlightColor != null) {
      return _colorHelper.getColor(widget.config.highlightColor!);
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
            context.push(AppRoutes.onboarding);
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
            widget.config.primaryButtonText.get(context),
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
              TextSpan(text: action.prefixText.get(context)),
              TextSpan(
                text: action.text.get(context),
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
