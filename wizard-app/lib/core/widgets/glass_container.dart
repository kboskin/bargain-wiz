import 'dart:ui';
import 'package:flutter/material.dart';

/// Glassmorphism container widget
/// Creates a frosted glass effect with blur and transparency
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final Color? color;
  final double opacity;
  final BorderRadius? borderRadius;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const GlassContainer({
    super.key,
    required this.child,
    this.blurSigma = 10.0,
    this.color,
    this.opacity = 0.2,
    this.borderRadius,
    this.border,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: borderRadius ?? BorderRadius.circular(16),
          border: border,
        ),
        child: ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: (color ?? Colors.white).withValues(alpha: opacity),
                borderRadius: borderRadius ?? BorderRadius.circular(16),
                border: border ??
                    Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

