import 'package:flutter/material.dart';

/// Full-screen gradient background that accepts colors and stops.
/// Reused by onboarding, paywall, and any screen that needs a remote-configurable gradient.
class ConfigurableGradientBackground extends StatelessWidget {
  const ConfigurableGradientBackground({
    super.key,
    required this.colors,
    this.stops,
    required this.child,
    this.begin = Alignment.topCenter,
    this.end = Alignment.bottomCenter,
  });

  final List<Color> colors;
  final List<double>? stops;
  final Widget child;
  final Alignment begin;
  final Alignment end;

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) return child;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: begin,
              end: end,
              colors: colors,
              stops: (stops != null && stops!.length == colors.length)
                  ? stops
                  : null,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
