import 'package:flutter/material.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';

/// Overlay shown on an image (or any content) while "uploading": a 3px teal
/// scan line with an 18px glow sweeping top→bottom (1.6s linear, infinite)
/// over a light dim. Use as the top layer of a [Stack] over the content.
class ScanningOverlay extends StatefulWidget {
  const ScanningOverlay({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.lineColor = WizColors.teal,
    this.dimColor = const Color(0x2914121B),
  });

  final double width;
  final double height;
  final double borderRadius;
  final Color lineColor;
  final Color dimColor;

  @override
  State<ScanningOverlay> createState() => _ScanningOverlayState();
}

class _ScanningOverlayState extends State<ScanningOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: WizMotion.scan,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Stack(
        children: [
          Container(
            width: widget.width,
            height: widget.height,
            color: widget.dimColor,
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final y = _controller.value * (widget.height + 24) - 12;
              return Positioned(
                left: 0,
                right: 0,
                top: y,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: widget.lineColor,
                    boxShadow: [
                      BoxShadow(
                        color: widget.lineColor.withValues(alpha: 0.55),
                        blurRadius: 18,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Wraps [child] (e.g. an image) and shows [ScanningOverlay] on top when
/// [isUploading] is true. Use for consistent upload loading state.
class ImageWithScanningOverlay extends StatelessWidget {
  const ImageWithScanningOverlay({
    super.key,
    required this.child,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.isUploading = false,
  });

  final Widget child;
  final double width;
  final double height;
  final double borderRadius;
  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (isUploading)
            ScanningOverlay(
              width: width,
              height: height,
              borderRadius: borderRadius,
            ),
        ],
      ),
    );
  }
}
