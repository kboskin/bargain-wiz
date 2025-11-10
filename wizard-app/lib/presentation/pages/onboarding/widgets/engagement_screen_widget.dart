import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/visual_asset_widget.dart';
import '../../../../data/models/onboarding_model.dart';

/// Widget for engagement-type onboarding screens
/// Displays title, description, and optional Lottie animation
class EngagementScreenWidget extends StatelessWidget {
  final EngagementScreenModel model;

  const EngagementScreenWidget({
    super.key,
    required this.model,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Visual (Lottie or placeholder)
          // Size is configurable via metadata, defaults to 200x200
          if (model.visual != null)
            _buildVisual(
              model.visual!,
              width: _getVisualWidth(),
              height: _getVisualHeight(),
            )
          else
            Container(
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
            ),
          const SizedBox(height: 48),

          // Title
          _buildStyledTitle(context, model.title),
          const SizedBox(height: 16),

          // Description (optional)
          if (model.description != null && model.description!.isNotEmpty) ...[
            _buildStyledDescription(context, model.description!),
          ],
        ],
      ),
    );
  }

  /// Get visual width from metadata or default to 200
  double _getVisualWidth() {
    if (model.metadata != null && model.metadata!.containsKey('width')) {
      final width = model.metadata!['width'];
      if (width is num) {
        return width.toDouble();
      }
    }
    return 200.0; // Default width
  }

  /// Get visual height from metadata or default to 200
  double _getVisualHeight() {
    if (model.metadata != null && model.metadata!.containsKey('height')) {
      final height = model.metadata!['height'];
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
    // Keywords to highlight with magical style
    final magicalKeywords = [
      'deals',
      'deal',
      'bargain',
      'bargains',
      'AI-powered',
      'AI',
      'smart',
      'magical',
      'magic',
      'best',
      'negotiation',
      'strategies',
      'analysis',
      'help',
      'get',
    ];

    // Split description into words and highlight keywords
    final words = description.split(' ');
    final textSpans = <TextSpan>[];

    for (final word in words) {
      // Remove punctuation for comparison
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
      final isMagical = magicalKeywords.any((keyword) => 
        cleanWord.contains(keyword.toLowerCase()) || 
        keyword.toLowerCase().contains(cleanWord)
      );

      if (isMagical) {
        // Magical highlight style - amber/yellow with glow effect
        textSpans.add(
          TextSpan(
            text: '$word ',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.amber.withValues(alpha: 0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
          ),
        );
      } else {
        // Regular text
        textSpans.add(
          TextSpan(
            text: '$word ',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.backgroundDark.withValues(alpha: 0.8),
            ),
          ),
        );
      }
    }

    return RichText(
      text: TextSpan(children: textSpans),
      textAlign: TextAlign.center,
    );
  }
}

