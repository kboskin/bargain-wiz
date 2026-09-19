import 'package:flutter/material.dart';

import 'package:appwizard/core/theme/option_style.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/wiz/frosted_surface.dart';
import 'package:appwizard/core/widgets/wiz/wiz_chip.dart';
import 'package:appwizard/features/profile/domain/profile_fields.dart';

/// Card title style shared by the Profile cards (Outfit 15/600).
const TextStyle profileCardTitle = WizType.cardTitle;

/// "Negotiation vibe": compact chips with the vibe dot, ink when selected + description.
/// [title] and [options] both come from the onboarding screen that asks the question, so the
/// card follows remote copy, colours and glyphs.
class ProfileVibeCard extends StatelessWidget {
  const ProfileVibeCard({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelect,
    this.title = 'Negotiation vibe',
  });

  final String title;
  final List<ProfileOption> options;
  final String? selectedValue;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = options.where((o) => o.value == selectedValue).firstOrNull ??
        (options.isNotEmpty ? options.first : null);
    final subtext = TemplateText.textOf(context, selected?.subtext);
    return FrostedSurface(
      radius: WizRadii.cardXl,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: profileCardTitle),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                if (OptionStyle.of(option) case final style)
                  WizChip(
                    compact: true,
                    label: TemplateText.textOf(context, option.shortLabel ?? option.label),
                    // The option's glyph tinted in its colour; inherits the chip foreground when selected.
                    leading: style.icon == null
                        ? null
                        : Icon(style.icon, color: option.value == selected?.value ? null : style.textColor),
                    dotColor: style.icon == null ? style.color : null,
                    selected: option.value == selected?.value,
                    fill: Colors.white,
                    textStyle: WizType.captionStrong,
                    onTap: () => onSelect(option.value),
                  ),
            ],
          ),
          if (subtext.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(subtext, style: WizType.caption),
          ],
        ],
      ),
    );
  }
}
