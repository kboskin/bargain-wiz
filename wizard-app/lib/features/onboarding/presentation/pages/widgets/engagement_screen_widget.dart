import 'package:flutter/material.dart';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/utils/color_helper.dart';
import 'package:appwizard/core/utils/text_highlight_helper.dart';
import 'package:appwizard/core/widgets/styled_description_widget.dart';
import 'package:appwizard/core/widgets/styled_rich_text_description_widget.dart';
import 'package:appwizard/core/widgets/styled_title_widget.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';

/// Widget for engagement-type onboarding screens
/// Displays title, description, and optional Lottie animation
class EngagementScreenWidget extends StatefulWidget {
  final EngagementScreenModel model;
  final Color? textColor;

  const EngagementScreenWidget({
    super.key,
    required this.model,
    this.textColor,
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
          StyledTitleWidget(
            title: widget.model.title.get(context),
            baseColor: widget.textColor ?? AppColors.backgroundDark,
            highlightWordsData: widget.model.metadata?.highlightWords?.title,
            highlightColor: widget.model.metadata?.highlightColor,
          ),
          const SizedBox(height: 16),

          // Description (optional)
          if (widget.model.description != null) ...[
            Builder(
              builder: (context) {
                final descriptionText = widget.model.description!.get(context);
                if (descriptionText.isNotEmpty) {
                  return StyledDescriptionWidget(
                    description: descriptionText,
                    highlightWordsData: widget.model.metadata?.highlightWords?.description,
                    highlightColor: _getHighlightColor(),
                    textHighlightHelper: _textHighlightHelper,
                    onRichTextDescription: (ctx, desc, data) => StyledRichTextDescriptionWidget(
                      description: desc,
                      highlightWordsData: data,
                      baseColor: widget.textColor ?? AppColors.backgroundDark,
                      highlightColor: _getHighlightColor(),
                      textAlign: TextAlign.center,
                    ),
                  );
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

  /// Get highlight color from metadata
  Color? _getHighlightColor() {
    final colorString = widget.model.metadata?.highlightColor;
    if (colorString != null && colorString.isNotEmpty) {
      return _colorHelper.getColor(colorString);
    }
    return null; // No color if not found
  }
}

