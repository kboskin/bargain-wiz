import 'package:flutter/material.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/wiz/frosted_surface.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/core/widgets/wiz/wiz_chip.dart';
import 'package:appwizard/core/widgets/wiz/wiz_sheet.dart';
import 'package:appwizard/features/profile/domain/profile_options.dart';

class ProfileSettingsRow {
  const ProfileSettingsRow({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;
}

/// Settings list card: rows with 12px vertical padding, dividers, value Figtree 14/600 + ›.
class ProfileSettingsCard extends StatelessWidget {
  const ProfileSettingsCard({super.key, required this.rows});

  final List<ProfileSettingsRow> rows;

  @override
  Widget build(BuildContext context) => FrostedSurface(
        radius: WizRadii.cardXl,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1, thickness: 1, color: WizColors.divider),
              _SettingsRow(row: rows[i]),
            ],
          ],
        ),
      );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.row});

  final ProfileSettingsRow row;

  @override
  Widget build(BuildContext context) => WizPressable(
        onTap: row.onTap,
        scale: 0.99,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(child: Text(row.label, style: WizType.bodyMdStrong)),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  row.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: WizType.bodySmBold.copyWith(color: WizColors.textSecondary),
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, size: 18, color: WizColors.textSecondary),
            ],
          ),
        ),
      );
}

/// Bottom sheet with chips to pick one [ProfileOption]; pops after [onPick].
/// [iconFor] supplies an optional leading chip icon per option.
Future<void> showProfileOptionSheet(
  BuildContext context, {
  required String title,
  required List<ProfileOption> options,
  required String? selected,
  required ValueChanged<String> onPick,
  IconData? Function(ProfileOption option)? iconFor,
}) =>
    WizSheet.show<void>(
      context,
      builder: (sheetContext) => WizSheet(
        title: title,
        onClose: () => Navigator.of(sheetContext).pop(),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              WizChip(
                label: TemplateText.textOf(sheetContext, o.label, fallback: o.value),
                leading: switch (iconFor?.call(o)) {
                  final icon? => Icon(icon),
                  null => null,
                },
                selected: o.value == selected,
                fill: Colors.white,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onPick(o.value);
                },
              ),
          ],
        ),
      ),
    );
