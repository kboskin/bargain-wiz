import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/asset_path_helper.dart';

/// Helper widget for rendering visual assets (Lottie, SVG, or Images)
/// Supports both network URLs and local assets
class VisualAssetWidget extends StatelessWidget {
  final String visualPath;
  final double width;
  final double height;

  const VisualAssetWidget({
    super.key,
    required this.visualPath,
    this.width = 200,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    // Determine file type from extension
    final lowerPath = visualPath.toLowerCase();
    final isLottie = lowerPath.endsWith('.json');
    final isSvg = lowerPath.endsWith('.svg');
    // PNG/JPG are handled as the default case (not Lottie or SVG)

    // Normalize asset path
    final normalizedPath = AssetPathHelper.normalizeAssetPath(visualPath);
    final isNetworkUrl = AssetPathHelper.isNetworkUrl(visualPath);

    Widget visualWidget;

    // Check if it's a network URL
    if (isNetworkUrl) {
      if (isLottie) {
        visualWidget = Lottie.network(visualPath, fit: BoxFit.contain);
      } else if (isSvg) {
        visualWidget = SvgPicture.network(visualPath, fit: BoxFit.contain);
      } else {
        // PNG/JPG from network
        visualWidget = Image.network(visualPath, fit: BoxFit.contain);
      }
    } else {
      // Local asset
      if (isLottie) {
        visualWidget = Lottie.asset(normalizedPath, fit: BoxFit.contain);
      } else if (isSvg) {
        visualWidget = SvgPicture.asset(normalizedPath, fit: BoxFit.contain);
      } else {
        // PNG/JPG from assets
        visualWidget = Image.asset(normalizedPath, fit: BoxFit.contain);
      }
    }

    return SizedBox(
      width: width,
      height: height,
      child: visualWidget,
    );
  }
}

