import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:flutter/material.dart';

/// Widget for image list-type onboarding screens
/// Displays a title and scrollable list of images
class ImageListScreenWidget extends StatelessWidget {
  final ImageListScreenModel model;

  const ImageListScreenWidget({
    super.key,
    required this.model,
  });

  @override
  Widget build(BuildContext context) {
    final title = model.title.get(context);

    // Get image spacing from metadata or default to 16
    final imageSpacing = _getImageSpacing();
    // Get image width from metadata or default to full width minus padding
    final imageWidth = _getImageWidth(context);
    // Get image height from metadata or null (auto-fit)
    final imageHeight = _getImageHeight();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Title
          Text(
            title,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppColors.backgroundDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Scrollable list of images
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: model.images.length,
              itemBuilder: (context, index) {
                final imagePath = model.images[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < model.images.length - 1 ? imageSpacing : 0,
                  ),
                  child: _buildImage(imagePath, imageWidth, imageHeight),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Build individual image widget
  Widget _buildImage(String imagePath, double? width, double? height) {
    return VisualAssetWidget(
      visualPath: imagePath,
      width: width ?? 200,
      height: height ?? 200,
      fit: BoxFit.contain,
    );
  }

  /// Get image spacing from metadata or default to 16
  double _getImageSpacing() {
    return model.metadata?.imageSpacing ?? 16.0;
  }

  /// Get image width from metadata or default to full width
  double? _getImageWidth(final BuildContext context) {
    if (model.metadata?.imageWidth != null) {
      return model.metadata?.imageWidth;
    }
    // Default to full width minus padding (40 on each side = 80 total)
    return MediaQuery.of(context).size.width - 80;
  }

  /// Get image height from metadata or null for auto-fit
  double? _getImageHeight() {
    return model.metadata?.imageHeight;
  }
}

