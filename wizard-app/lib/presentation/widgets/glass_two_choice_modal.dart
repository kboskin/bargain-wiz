import 'package:flutter/material.dart';

import 'package:appwizard/core/widgets/glass_container.dart';
import 'package:appwizard/core/widgets/rc_metadata_button.dart';
import 'package:appwizard/core/widgets/styled_title_widget.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/data/models/remote_config/button_config.dart';

/// Reusable glass-styled modal with drag handle, close button,
/// optional visual, title, and two permission-style buttons.
/// Use as bottom sheet content or inside [Dialog] for a custom alert.
/// When [borderRadius] is null, uses top-only radius (bottom sheet); pass [BorderRadius.circular(32)] for dialog.
class GlassTwoChoiceModal extends StatelessWidget {
  const GlassTwoChoiceModal({
    super.key,
    required this.title,
    required this.primaryButtonConfig,
    required this.onPrimaryPressed,
    required this.secondaryButtonConfig,
    required this.onSecondaryPressed,
    required this.onClose,
    this.visualPath,
    this.visualWidth = 80.0,
    this.visualHeight = 80.0,
    this.borderRadius,
    this.padding,
    this.titleHighlightWords,
    this.titleHighlightColor,
  });

  final String title;
  final ButtonConfig primaryButtonConfig;
  final VoidCallback onPrimaryPressed;
  final ButtonConfig secondaryButtonConfig;
  final VoidCallback onSecondaryPressed;
  final VoidCallback onClose;
  final String? visualPath;
  final double visualWidth;
  final double visualHeight;
  /// When null, uses top-only radius (for bottom sheet). For dialog use [BorderRadius.circular(32)].
  final BorderRadius? borderRadius;
  /// When null, uses default padding (bottom includes viewInsets for bottom sheet).
  final EdgeInsets? padding;
  /// Optional highlight config for title (same as onboarding); e.g. {"satisfied": "#4ECDC4"}.
  final dynamic titleHighlightWords;
  /// Default highlight color (hex string) when word has no specific color.
  final String? titleHighlightColor;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ??
        const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        );
    final effectivePadding = padding ??
        EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        );
    return GlassContainer(
      blurSigma: 20.0,
      color: Colors.white,
      opacity: 0.25,
      borderRadius: effectiveRadius,
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.3),
        width: 1.5,
      ),
      padding: effectivePadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDragHandle(),
          _buildCloseButton(context),
          if (visualPath != null && visualPath!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Center(
              child: VisualAssetWidget(
                visualPath: visualPath!,
                width: visualWidth,
                height: visualHeight,
              ),
            ),
            const SizedBox(height: 20),
          ],
          StyledTitleWidget(
            title: title,
            baseColor: Colors.white,
            highlightWordsData: titleHighlightWords,
            highlightColor: titleHighlightColor,
            fontSize: 22.0,
            fontSizeHighlight: 26.0,
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 56,
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: RCMetadataButton(
                      config: secondaryButtonConfig,
                      onPressed: onSecondaryPressed,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      borderRadius: 16,
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: RCMetadataButton(
                      config: primaryButtonConfig,
                      onPressed: onPrimaryPressed,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      borderRadius: 16,
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: _hasPrimaryFloatingVisual
                ? (primaryButtonConfig.buttonVisualHeight ?? 60.0) + 28
                : 16,
          ),
        ],
      ),
    );
  }

  bool get _hasPrimaryFloatingVisual {
    final path = primaryButtonConfig.buttonVisual;
    return path != null && path.isNotEmpty;
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          icon: Icon(
            Icons.close_rounded,
            color: Colors.white.withValues(alpha: 0.9),
            size: 24,
          ),
          onPressed: onClose,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(8),
            minimumSize: const Size(40, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}
