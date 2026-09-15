import 'package:flutter/material.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/wiz/frosted_surface.dart';
import 'package:appwizard/core/widgets/wiz/wiz_chip.dart';
import 'package:appwizard/features/profile/presentation/widgets/profile_vibe_card.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';

/// Developer row (debug / dev builds only): tier override chips free · basic · premium · off.
class ProfileDeveloperCard extends StatelessWidget {
  const ProfileDeveloperCard({super.key, required this.tierOverride, required this.onChange});

  final SubscriptionTier? tierOverride;
  final ValueChanged<SubscriptionTier?> onChange;

  @override
  Widget build(BuildContext context) => FrostedSurface(
        radius: WizRadii.cardXl,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Expanded(child: Text('Tier override', style: profileCardTitle)),
                Text('Debug', style: WizType.footnote),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in SubscriptionTier.values)
                  WizChip(
                    compact: true,
                    label: t.name,
                    selected: tierOverride == t,
                    fill: Colors.white,
                    onTap: () => onChange(t),
                  ),
                WizChip(
                  compact: true,
                  label: 'off',
                  selected: tierOverride == null,
                  fill: Colors.white,
                  onTap: () => onChange(null),
                ),
              ],
            ),
          ],
        ),
      );
}
