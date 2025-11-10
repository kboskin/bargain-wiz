import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/visual_asset_widget.dart';
import '../../../../data/models/onboarding_model.dart';

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
  @override
  Widget build(BuildContext context) {
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
          _buildStyledTitle(context, widget.model.title),
          const SizedBox(height: 16),

          // Description (optional)
          if (widget.model.description != null && widget.model.description!.isNotEmpty) ...[
            _buildStyledDescription(context, widget.model.description!),
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
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
        color: AppColors.backgroundDark,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildStyledDescription(BuildContext context, String description) {
    // Check if description contains HTML tags
    final hasHtml = RegExp(r'<[^>]+>').hasMatch(description);
    
    if (hasHtml) {
      // Parse and render HTML with custom styling (aligned with welcome screen)
      return Html(
        data: description,
        style: {
          'body': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            textAlign: TextAlign.center,
            fontSize: FontSize(Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16),
            color: AppColors.backgroundDark.withValues(alpha: 0.8),
            lineHeight: const LineHeight(1.5),
          ),
          'span.highlight': Style(
            color: Colors.amber,
            fontWeight: FontWeight.bold,
            fontSize: FontSize(20),
          ),
          'strong': Style(
            color: Colors.amber,
            fontWeight: FontWeight.bold,
            fontSize: FontSize(20),
          ),
        },
      );
    } else {
      // Plain text - render as regular text (aligned with welcome screen)
      return Text(
        description,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: AppColors.backgroundDark.withValues(alpha: 0.9),
          height: 1.5,
          fontSize: 18,
        ),
        textAlign: TextAlign.center,
      );
    }
  }
}

