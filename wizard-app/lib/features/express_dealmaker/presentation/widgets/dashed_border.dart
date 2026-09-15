import 'package:flutter/material.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';

/// Rounded rectangle with a dashed stroke (drop zone / "+ Add" tiles).
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    required this.child,
    super.key,
    this.color = WizColors.borderStrong,
    this.strokeWidth = 2,
    this.radius = 24,
    this.dash = 8,
    this.gap = 6,
    this.fill,
  });

  final Widget child;
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dash;
  final double gap;
  /// Optional background fill inside the border.
  final Color? fill;

  @override
  Widget build(final BuildContext context) => CustomPaint(
        painter: DashedRRectPainter(
          color: color,
          strokeWidth: strokeWidth,
          radius: radius,
          dash: dash,
          gap: gap,
        ),
        child: fill == null
            ? child
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(radius),
                ),
                child: child,
              ),
      );
}

/// Paints a dashed rounded-rectangle outline inset by half the stroke.
class DashedRRectPainter extends CustomPainter {
  const DashedRRectPainter({
    required this.color,
    this.strokeWidth = 2,
    this.radius = 24,
    this.dash = 8,
    this.gap = 6,
  });

  final Color color;
  final double strokeWidth;
  final double radius;
  final double dash;
  final double gap;

  @override
  void paint(final Canvas canvas, final Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(final DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.radius != radius ||
      oldDelegate.dash != dash ||
      oldDelegate.gap != gap;
}
