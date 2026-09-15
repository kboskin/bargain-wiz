import 'package:flutter/material.dart';

import 'package:appwizard/core/config/wiz_catalog.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/wiz/frosted_surface.dart';
import 'package:appwizard/core/widgets/wiz/wiz_chip.dart';

/// Card title style shared by the Profile cards (Outfit 15/600).
const TextStyle profileCardTitle = WizType.cardTitle;

/// "Negotiation vibe": compact chips with the vibe dot, ink when selected + description.
class ProfileVibeCard extends StatelessWidget {
  const ProfileVibeCard({
    super.key,
    required this.vibes,
    required this.selectedId,
    required this.onSelect,
  });

  final List<VibeDef> vibes;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = vibes.where((v) => v.id == selectedId).firstOrNull ??
        (vibes.isNotEmpty ? vibes.first : null);
    return FrostedSurface(
      radius: WizRadii.cardXl,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Negotiation vibe', style: profileCardTitle),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in vibes)
                WizChip(
                  compact: true,
                  label: v.shortOf(context),
                  dotColor: v.color,
                  selected: v.id == selected?.id,
                  fill: Colors.white,
                  textStyle: WizType.captionStrong,
                  onTap: () => onSelect(v.id),
                ),
            ],
          ),
          if (selected != null) ...[
            const SizedBox(height: 10),
            Text(selected.subtextOf(context), style: WizType.caption),
          ],
        ],
      ),
    );
  }
}
