import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';

/// Frosted white surface from the redesign (replaces low-opacity glass):
/// white 72% (default) + backdrop blur σ10 + 1px white 95% border + soft shadow.
class FrostedSurface extends StatelessWidget {
  const FrostedSurface({
    super.key,
    required this.child,
    this.radius = WizRadii.cardLg,
    this.borderRadius,
    this.padding,
    this.margin,
    this.color = WizColors.frosted,
    this.borderColor = WizColors.frostedBorder,
    this.borderWidth = 1,
    this.blurSigma = 10,
    this.shadow = WizShadows.card,
    this.width,
    this.height,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final double radius;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color color;
  final Color? borderColor;
  final double borderWidth;
  final double blurSigma;
  final List<BoxShadow>? shadow;
  final double? width;
  final double? height;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(radius);
    Widget inner = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: br,
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: borderWidth),
      ),
      child: child,
    );
    if (blurSigma > 0) {
      inner = ClipRRect(
        clipBehavior: clipBehavior,
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: inner,
        ),
      );
    }
    return Container(
      margin: margin,
      decoration: BoxDecoration(borderRadius: br, boxShadow: shadow),
      child: inner,
    );
  }
}
