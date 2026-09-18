import 'package:flutter/material.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';

/// The app's gradient with a small spinner, using only compile-time colours: no Remote
/// Config, no dependency container, no assets to decode. Shown while [AppBootstrap] runs and
/// for the one frame the home route needs to read the onboarding flag.
class AppSplash extends StatelessWidget {
  const AppSplash({super.key, this.message});

  /// Set when startup failed; [onRetry] then gets a button.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: WizColors.angledGradient(
          WizColors.appGradientColors,
          WizColors.appGradientStops,
          WizColors.appGradientAngleDeg,
        ),
      ),
      // Deliberately static: native Firebase initialization blocks the platform thread for
      // a moment after this frame, and a stalled animation reads as a frozen app.
      child: text == null
          ? const SizedBox.expand()
          : Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(text, textAlign: TextAlign.center, style: WizType.bodyMd),
              ),
            ),
    );
  }
}

/// The very first frame, before anything is initialized: one flat brand colour, no
/// `MaterialApp` (no theme, no localizations, no navigator), no gradient shader and no
/// assets. It matches the native launch background, so the handover is invisible, and the
/// real gradient arrives with [AppSplash] / the app itself.
class BootSplash extends StatelessWidget {
  const BootSplash({super.key, this.message, this.onRetry});

  /// Set when startup failed; tapping anywhere then calls [onRetry].
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final text = message;
    Widget content = ColoredBox(
      color: WizColors.appGradientColors.first,
      child: text == null
          ? const SizedBox.expand()
          : Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: DefaultTextStyle(
                  style: WizType.bodyMd,
                  textAlign: TextAlign.center,
                  child: Text('$text\n\nTap to try again'),
                ),
              ),
            ),
    );
    if (text != null && onRetry != null) {
      content = GestureDetector(onTap: onRetry, child: content);
    }
    return Directionality(textDirection: TextDirection.ltr, child: content);
  }
}
