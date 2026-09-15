import 'package:flutter/material.dart';

import 'package:appwizard/core/config/wiz_catalog.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/wiz/frosted_surface.dart';
import 'package:appwizard/features/profile/presentation/widgets/profile_vibe_card.dart';

/// "How hard you push": header with "{emoji} {label}" in the stop colour + 5-segment tappable meter.
class ProfilePushCard extends StatelessWidget {
  const ProfilePushCard({
    super.key,
    required this.levels,
    required this.current,
    required this.onSelect,
  });

  final List<PushDef> levels;
  final PushDef current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final currentIndex = levels.indexWhere((l) => l.value == current.value);
    return FrostedSurface(
      radius: WizRadii.cardXl,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Expanded(child: Text('How hard you push', style: profileCardTitle)),
              Text(
                '${current.emoji} ${current.labelOf(context)}',
                style: WizType.captionStrong.copyWith(color: current.color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < levels.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: levels[i].labelOf(context),
                    selected: i == currentIndex,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelect(levels[i].value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        height: 14,
                        decoration: BoxDecoration(
                          color: i <= currentIndex ? current.color : WizColors.inkMeter,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
