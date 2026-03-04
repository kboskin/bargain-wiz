import 'package:flutter/material.dart';

import 'package:appwizard/core/widgets/visual_asset_widget.dart';

/// Wraps a button with an optional floating Lottie/image positioned below it.
/// Used by permission screen for the "magic stick" near the primary action.
class ButtonWithFloatingVisual extends StatelessWidget {
  const ButtonWithFloatingVisual({
    super.key,
    required this.child,
    this.visualPath,
    this.visualWidth = 60.0,
    this.visualHeight = 60.0,
  });

  final Widget child;
  final String? visualPath;
  final double visualWidth;
  final double visualHeight;

  @override
  Widget build(BuildContext context) {
    if (visualPath == null || visualPath!.isEmpty) return child;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        child,
        Positioned(
          bottom: -visualHeight - 12,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: VisualAssetWidget(
                visualPath: visualPath!,
                width: visualWidth,
                height: visualHeight,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
