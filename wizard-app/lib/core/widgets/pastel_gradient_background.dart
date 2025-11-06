import 'dart:ui';
import 'package:flutter/material.dart';
import '../di/injection_container.dart' as di;
import '../services/remote_config_service.dart';

/// Gradient background widget for the entire application
/// Configurable via Remote Config with optional blur/glass effect
class PastelGradientBackground extends StatelessWidget {
  final Widget child;
  final bool showNoiseTexture;
  final double blurSigma; // Blur intensity (0.0 = no blur, higher = more blur)

  const PastelGradientBackground({
    super.key,
    required this.child,
    this.showNoiseTexture = false,
    this.blurSigma = 0.0, // Default no blur
  });

  /// Default gradient colors (fallback if Remote Config not available)
  /// Matches Bargain Wizard brand: purple (wizard) + orange (warmth) + cyan (tech)
  static const List<Color> _defaultColors = [
    Color(0xFFE8D5FF), // Soft purple (top) - wizard hat theme
    Color(0xFFFFE5B4), // Warm peach/orange (mid) - logo background circle
    Color(0xFFE0F7FA), // Light cyan (bottom) - tech/digital feel
  ];

  static const List<double> _defaultStops = [0.0, 0.5, 1.0];

  @override
  Widget build(BuildContext context) {
    // Get gradient config from Remote Config
    final remoteConfigService = di.sl<RemoteConfigService>();
    final gradientConfig = remoteConfigService.getGradientBackgroundConfig();

    // Use Remote Config values or fallback to defaults
    final colors = gradientConfig?.colorObjects ?? _defaultColors;
    final stops = gradientConfig?.stops ?? _defaultStops;

    Widget content = child;

    // Optional: very subtle grain/noise overlay
    if (showNoiseTexture) {
      content = Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  image: const DecorationImage(
                    image: AssetImage('assets/noise_4pct.png'),
                    fit: BoxFit.cover,
                    opacity: 0.06, // keep it *very* subtle
                    filterQuality: FilterQuality.low,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget background = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: stops,
        ),
      ),
    );

    // Apply blur effect if specified
    if (blurSigma > 0.0) {
      background = ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: background,
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          background,
          content,
        ],
      ),
    );
  }
}

