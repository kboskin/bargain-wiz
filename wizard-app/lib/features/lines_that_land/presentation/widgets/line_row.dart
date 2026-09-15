import 'package:flutter/material.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';

/// One copyable line. Tab variant: radius 16, 1px border. Sheet variant ([pill]): radius 999, 1.5px.
/// Copied state: teal border, teal 20% fill, ✓ glyph.
class LineRow extends StatelessWidget {
  const LineRow({
    super.key,
    required this.text,
    required this.copied,
    required this.onTap,
    this.pill = false,
  });

  final String text;
  final bool copied;
  final VoidCallback onTap;
  final bool pill;

  @override
  Widget build(BuildContext context) => WizPressable(
        onTap: onTap,
        scale: 0.985,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: copied ? WizColors.tealSoft : Colors.white,
            borderRadius: BorderRadius.circular(pill ? WizRadii.chip : WizRadii.thumbXl),
            border: Border.all(
              color: copied ? WizColors.teal : WizColors.border,
              width: pill ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: WizType.bodyMdStrong.copyWith(height: pill ? 1.3 : 1.35),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                copied ? Icons.check_rounded : Icons.copy_rounded,
                size: 16,
                color: copied
                    ? WizColors.tealText
                    : (pill ? WizColors.textSecondary : WizColors.textTertiary),
              ),
            ],
          ),
        ),
      );
}
