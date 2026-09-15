import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/wiz/frosted_surface.dart';

/// Bottom-sheet shell: frosted 86% (or custom color), radius 32 top, 40×5 handle, optional title + close.
class WizSheet extends StatelessWidget {
  const WizSheet({
    super.key,
    required this.child,
    this.title,
    this.onClose,
    this.color = WizColors.frostedStrong,
    this.handleColor,
    this.titleStyle,
    this.closeColor = WizColors.ink,
    this.padding = const EdgeInsets.fromLTRB(24, 12, 24, 24),
    this.maxHeightFraction = 0.78,
    this.scrollable = false,
  });

  final Widget child;
  final String? title;
  final VoidCallback? onClose;
  final Color color;
  final Color? handleColor;
  final TextStyle? titleStyle;
  final Color closeColor;
  final EdgeInsets padding;
  final double maxHeightFraction;
  final bool scrollable;

  /// Shows a [WizSheet] with the scrim + blur from the handoff.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool isDismissible = true,
  }) =>
      showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        isDismissible: isDismissible,
        backgroundColor: Colors.transparent,
        barrierColor: WizColors.scrim,
        builder: builder,
      );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDark = color.computeLuminance() < 0.4;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: handleColor ??
                  (isDark ? Colors.white.withValues(alpha: 0.25) : WizColors.borderStrong),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        if (title != null || onClose != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title ?? '',
                    style: titleStyle ??
                        WizType.titleXs.copyWith(color: isDark ? Colors.white : WizColors.ink),
                  ),
                ),
                if (onClose != null)
                  _CloseButton(onPressed: onClose!, color: closeColor, dark: isDark),
              ],
            ),
          ),
        if (scrollable) Flexible(child: SingleChildScrollView(child: child)) else child,
      ],
    );
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * maxHeightFraction),
        child: FrostedSurface(
          color: color,
          borderColor: isDark ? null : WizColors.frostedBorder,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(WizRadii.sheet)),
          shadow: WizShadows.sheet,
          blurSigma: isDark ? 0 : 12,
          padding: EdgeInsets.fromLTRB(
            padding.left,
            padding.top,
            padding.right,
            padding.bottom + media.padding.bottom,
          ),
          child: body,
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed, required this.color, required this.dark});

  final VoidCallback onPressed;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: dark ? Colors.white.withValues(alpha: 0.12) : WizColors.segmentTrack,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(Icons.close_rounded, size: 18, color: dark ? Colors.white : color),
        ),
      );
}

/// Centred dialog shell: frosted 90%, radius 28, inset 28.
class WizDialog extends StatelessWidget {
  const WizDialog({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.onClose,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onClose;

  static Future<T?> show<T>(BuildContext context, {required WidgetBuilder builder}) =>
      showGeneralDialog<T>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
        barrierColor: WizColors.scrim,
        transitionDuration: WizMotion.sheet,
        pageBuilder: (ctx, a1, a2) => builder(ctx),
        transitionBuilder: (ctx, a1, a2, child) {
          final curved = CurvedAnimation(parent: a1, curve: Curves.easeOutCubic);
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6 * a1.value, sigmaY: 6 * a1.value),
            child: FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
                    .animate(curved),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
                  child: child,
                ),
              ),
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                FrostedSurface(
                  color: WizColors.frostedDialog,
                  radius: WizRadii.cardHero,
                  shadow: WizShadows.dialog,
                  padding: padding,
                  child: child,
                ),
                if (onClose != null)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _CloseButton(onPressed: onClose!, color: WizColors.ink, dark: false),
                  ),
              ],
            ),
          ),
        ),
      );
}
