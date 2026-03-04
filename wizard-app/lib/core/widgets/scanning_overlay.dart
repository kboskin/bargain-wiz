import 'package:flutter/material.dart';

/// Overlay shown on an image (or any content) while "uploading": a moving scan
/// line + dim overlay. Use as the top layer of a [Stack] over the content.
/// Same loading state as text-mode attachments.
class ScanningOverlay extends StatefulWidget {
  const ScanningOverlay({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<ScanningOverlay> createState() => _ScanningOverlayState();
}

class _ScanningOverlayState extends State<ScanningOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

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
            color: Colors.black26,
          ),
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Positioned(
                left: 0,
                right: 0,
                top: _animation.value * (widget.height + 12) - 6,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
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
