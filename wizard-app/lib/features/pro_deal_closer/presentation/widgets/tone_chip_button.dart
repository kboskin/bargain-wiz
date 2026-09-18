import 'package:appwizard/core/config/wiz_catalog.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:flutter/material.dart';

/// Header tone chip button "{glyph} {Tone short} ▾": soft vibe tint with the AA-safe
/// [VibeDef.chipTextColor]; tapping cycles to the next tone.
class ToneChipButton extends StatelessWidget {
  const ToneChipButton({super.key, required this.vibe, required this.onTap});

  final VibeDef vibe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: vibe.labelOf(context),
        child: WizPressable(
          onTap: onTap,
          scale: 0.97,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: vibe.color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(WizRadii.chip),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (vibe.icon != null) ...[
                  Icon(vibe.icon, size: 12, color: vibe.chipTextColor),
                  const SizedBox(width: 5),
                ],
                Text('${vibe.shortOf(context)} ▾', style: WizType.chip.copyWith(color: vibe.chipTextColor)),
              ],
            ),
          ),
        ),
      );
}
