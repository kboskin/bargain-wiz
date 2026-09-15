import 'package:flutter/material.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';

/// Full-screen gradient background that accepts colors, stops and a CSS-style angle.
/// Reused by onboarding, paywall, and any screen that needs a remote-configurable gradient.
class ConfigurableGradientBackground extends StatelessWidget {
  const ConfigurableGradientBackground({
    super.key,
    required this.colors,
    this.stops,
    required this.child,
    this.angleDeg = WizColors.appGradientAngleDeg,
  });

  final List<Color> colors;
  final List<double>? stops;
  final Widget child;
  /// CSS-style angle in degrees (0 = bottom→top, 90 = left→right, 165 = design default).
  final double angleDeg;

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) return child;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: WizColors.angledGradient(colors, stops, angleDeg),
          ),
        ),
        child,
      ],
    );
  }
}
