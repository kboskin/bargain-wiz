import 'package:flutter/material.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';

/// Pill chip: padding 11×16 (or compact 8×12), radius 999, 1.5px border.
/// Unselected: white 80% + border. Selected: [selectedColor] fill (ink by default) + contrasting text.
class WizChip extends StatelessWidget {
  const WizChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.selectedColor = WizColors.ink,
    this.selectedTextColor,
    this.borderColor = WizColors.border,
    this.fill = const Color(0xCCFFFFFF),
    this.textColor = WizColors.ink,
    this.dotColor,
    this.compact = false,
    this.leading,
    this.textStyle,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color selectedColor;
  final Color? selectedTextColor;
  final Color borderColor;
  final Color fill;
  final Color textColor;
  /// Optional 8px dot before the label (vibe color).
  final Color? dotColor;
  final bool compact;
  /// Optional leading widget; an [Icon] without explicit colour/size inherits the chip's.
  final Widget? leading;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? (selectedTextColor ?? contrastOn(selectedColor))
        : textColor;
    return WizPressable(
      onTap: onTap,
      scale: 0.97,
      child: Container(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? selectedColor : fill,
          borderRadius: BorderRadius.circular(WizRadii.chip),
          border: Border.all(
            color: selected ? selectedColor : borderColor,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              IconTheme.merge(
                data: IconThemeData(color: fg, size: compact ? 13 : 15),
                child: leading!,
              ),
              const SizedBox(width: 6),
            ],
            if (dotColor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: (textStyle ?? (compact ? WizType.chip : WizType.bodySmBold))
                  .copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }

  /// Ink on light accent colors, white on dark ones.
  static Color contrastOn(Color bg) {
    final l = bg.computeLuminance();
    return l > 0.5 ? WizColors.ink : Colors.white;
  }
}

/// Small solid tag (e.g. yellow "Vision" / "Recommended", intent tags).
class WizTag extends StatelessWidget {
  const WizTag({
    super.key,
    required this.label,
    this.color = WizColors.yellow,
    this.textColor = WizColors.ink,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    this.style,
  });

  final String label;
  final Color color;
  final Color textColor;
  final EdgeInsets padding;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(WizRadii.chip),
        ),
        child: Text(label, style: (style ?? WizType.chipSm).copyWith(color: textColor)),
      );
}
