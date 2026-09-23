import 'package:flutter/material.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';

/// Primary CTA: 56h, radius 28, ink fill, white Outfit 17/600, pressed scale .98, disabled opacity .4.
class WizPrimaryButton extends StatelessWidget {
  const WizPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.trailing,
    this.height = 56,
    this.color = WizColors.ink,
    this.textColor = Colors.white,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final Widget? trailing;
  final double height;
  final Color color;
  final Color textColor;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        if (loading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: textColor),
          )
        else
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: WizType.cta.copyWith(color: textColor),
            ),
          ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
    return _Pressable(
      enabled: enabled,
      onTap: onPressed,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled || loading ? 1 : 0.4,
        child: Container(
          height: height,
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(height / 2),
            boxShadow: enabled ? WizShadows.pill : null,
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Secondary CTA: 52h, radius 26, white fill, 1.5px border, Outfit 15/600 ink.
class WizSecondaryButton extends StatelessWidget {
  const WizSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.trailing,
    this.height = 52,
    this.fill = Colors.white,
    this.borderColor = WizColors.border,
    this.textColor = WizColors.ink,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final Widget? trailing;
  final double height;
  final Color fill;
  final Color borderColor;
  final Color textColor;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return _Pressable(
      enabled: enabled,
      onTap: onPressed,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          height: height,
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WizType.ctaSm.copyWith(color: textColor),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Glow button (permission / rate): teal fill with dark teal text and a pulsing ring,
/// or grey fill with white text.
class WizGlowButton extends StatefulWidget {
  const WizGlowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = WizColors.teal,
    this.textColor = WizColors.tealInk,
    this.pulse = true,
    this.height = 56,
    this.leading,
  });

  const WizGlowButton.grey({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 52,
    this.leading,
  })  : color = WizColors.greyGlow,
        textColor = Colors.white,
        pulse = false;

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final bool pulse;
  final double height;
  final Widget? leading;

  @override
  State<WizGlowButton> createState() => _WizGlowButtonState();
}

class _WizGlowButtonState extends State<WizGlowButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: WizMotion.pulse,
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return _Pressable(
      enabled: enabled,
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = _c.value;
          final ring = widget.pulse ? 12.0 * t : 0.0;
          final alpha = widget.pulse ? (0.55 * (1 - t)) : 0.0;
          return Container(
            height: widget.height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(widget.height / 2),
              boxShadow: [
                if (widget.pulse)
                  BoxShadow(
                    color: widget.color.withValues(alpha: alpha),
                    spreadRadius: ring,
                  ),
              ],
            ),
            alignment: Alignment.center,
            child: child,
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.leading != null) ...[widget.leading!, const SizedBox(width: 8)],
            // The label gives way rather than overflowing: with a leading visual and two
            // of these side by side, a 320 pt phone leaves each button under 135 pt.
            Flexible(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: WizType.cta.copyWith(color: widget.textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round icon button: 40–46px circle. `ink` for composer actions, white with shadow for back.
class WizRoundIconButton extends StatelessWidget {
  const WizRoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 44,
    this.color = WizColors.ink,
    this.iconColor = Colors.white,
    this.iconSize = 20,
    this.shadow,
    this.tooltip,
    this.child,
  });

  const WizRoundIconButton.white({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 40,
    this.iconSize = 20,
    this.tooltip,
    this.child,
  })  : color = Colors.white,
        iconColor = WizColors.ink,
        shadow = WizShadows.roundButton;

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color color;
  final Color iconColor;
  final double iconSize;
  final List<BoxShadow>? shadow;
  final String? tooltip;
  /// Optional custom child replacing the icon (e.g. equalizer while recording).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    Widget button = _Pressable(
      enabled: enabled,
      onTap: onPressed,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: shadow,
          ),
          alignment: Alignment.center,
          child: child ?? Icon(icon, size: iconSize, color: iconColor),
        ),
      ),
    );
    if (tooltip != null) button = Tooltip(message: tooltip!, child: button);
    return button;
  }
}

/// Back chevron in a 40px white circle (top-left of headers).
class WizBackChevron extends StatelessWidget {
  const WizBackChevron({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => WizRoundIconButton.white(
        icon: Icons.chevron_left_rounded,
        iconSize: 24,
        onPressed: onPressed,
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      );
}

/// Small text link button (e.g. "See all", "Why this works", "Restore Purchases").
class WizTextLink extends StatelessWidget {
  const WizTextLink({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = WizColors.purple,
    this.underline = false,
    this.style,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool underline;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Text(
            label,
            style: (style ?? WizType.captionStrong).copyWith(
              color: color,
              decoration: underline ? TextDecoration.underline : null,
              decorationColor: color,
            ),
          ),
        ),
      );
}

/// Scale-on-press wrapper (.98) shared by buttons and cards.
class WizPressable extends StatelessWidget {
  const WizPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.scale = 0.98,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool enabled;

  @override
  Widget build(BuildContext context) => _Pressable(
        enabled: enabled && (onTap != null || onLongPress != null),
        onTap: onTap,
        onLongPress: onLongPress,
        scale: scale,
        child: child,
      );
}

class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.child,
    required this.enabled,
    this.onTap,
    this.onLongPress,
    this.scale = 0.98,
  });

  final Widget child;
  final bool enabled;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: widget.enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: widget.enabled ? () => setState(() => _down = false) : null,
        onTap: widget.enabled ? widget.onTap : null,
        onLongPress: widget.enabled ? widget.onLongPress : null,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}
