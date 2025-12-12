import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/utils/asset_path_helper.dart';

/// Helper widget for rendering visual assets (Lottie, SVG, or Images)
/// Supports both network URLs and local assets
class VisualAssetWidget extends StatefulWidget {
  const VisualAssetWidget({
    super.key,
    required this.visualPath,
    this.width = 200,
    this.height = 200,
    this.fit = BoxFit.contain,
  });

  final String visualPath;
  final double width;
  final double height;
  final BoxFit fit;

  @override
  State<VisualAssetWidget> createState() => _VisualAssetWidgetState();
}

class _VisualAssetWidgetState extends State<VisualAssetWidget> {
  AssetPathHelper? _cachedAssetPathHelper;

  @override
  Widget build(BuildContext context) {
    // Cache DI lookup
    _cachedAssetPathHelper ??= di.sl<AssetPathHelper>();
    
    // Determine file type from extension
    final lowerPath = widget.visualPath.toLowerCase();
    final isLottie = lowerPath.endsWith('.json');
    final isSvg = lowerPath.endsWith('.svg');
    // PNG/JPG are handled as the default case (not Lottie or SVG)

    // Normalize asset path
    final normalizedPath = _cachedAssetPathHelper!.normalizeAssetPath(widget.visualPath);
    final isNetworkUrl = _cachedAssetPathHelper!.isNetworkUrl(widget.visualPath);

    Widget visualWidget;

    // Check if it's a network URL
    if (isNetworkUrl) {
      if (isLottie) {
        visualWidget = Lottie.network(
          widget.visualPath,
          fit: widget.fit,
          frameRate: const FrameRate(60),
          options: LottieOptions(enableMergePaths: true),
        );
      } else if (isSvg) {
        visualWidget = SvgPicture.network(widget.visualPath, fit: widget.fit);
      } else {
        // PNG/JPG from network
        visualWidget = Image.network(widget.visualPath, fit: widget.fit);
      }
    } else {
      // Local asset
      if (isLottie) {
        visualWidget = Lottie.asset(
          normalizedPath,
          fit: widget.fit,
          frameRate: FrameRate(60),
          options: LottieOptions(enableMergePaths: true),
        );
      } else if (isSvg) {
        visualWidget = SvgPicture.asset(normalizedPath, fit: widget.fit);
      } else {
        // PNG/JPG from assets
        visualWidget = Image.asset(normalizedPath, fit: widget.fit);
      }
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Center(
        child: visualWidget,
      ),
    );
  }
}

