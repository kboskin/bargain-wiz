import 'package:appwizard/core/theme/option_style.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/features/profile/domain/profile_fields.dart';
import 'package:flutter/material.dart';

/// Header tone chip button "{glyph} {Tone short} ▾": a soft tint of the colour the tone option
/// configures, with a text colour that reads on it; tapping cycles to the next tone.
class ToneChipButton extends StatelessWidget {
  const ToneChipButton({super.key, required this.tone, required this.onTap});

  /// The configured option for the stored tone; null renders nothing.
  final ProfileOption? tone;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final option = tone;
    if (option == null) return const SizedBox.shrink();
    final style = OptionStyle.of(option);
    final label = TemplateText.textOf(context, option.shortLabel ?? option.label);
    return Semantics(
      button: true,
      label: TemplateText.textOf(context, option.label),
      child: WizPressable(
        onTap: onTap,
        scale: 0.97,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: style.color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(WizRadii.chip),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (style.icon != null) ...[
                Icon(style.icon, size: 12, color: style.textColor),
                const SizedBox(width: 5),
              ],
              Text('$label ▾', style: WizType.chip.copyWith(color: style.textColor)),
            ],
          ),
        ),
      ),
    );
  }
}
