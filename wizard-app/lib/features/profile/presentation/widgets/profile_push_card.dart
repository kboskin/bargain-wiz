import 'package:flutter/material.dart';

import 'package:appwizard/core/theme/option_style.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/wiz/frosted_surface.dart';
import 'package:appwizard/features/profile/domain/profile_fields.dart';
import 'package:appwizard/features/profile/presentation/widgets/profile_vibe_card.dart';

/// "How hard you push": header with "{emoji} {label}" in the stop colour + a tappable meter,
/// one segment per configured stop. [title], the stops and their colours all come from the
/// onboarding screen that asks the question.
class ProfilePushCard extends StatelessWidget {
  const ProfilePushCard({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelect,
    this.title = 'How hard you push',
  });

  final String title;
  final List<ProfileOption> options;

  /// The stored stop (`20`, `60`, …); the first stop is shown when it is unanswered.
  final String? selectedValue;

  /// Called with the picked stop's value, as an int when the stop is numeric.
  final ValueChanged<dynamic> onSelect;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    final index = options.indexWhere((o) => o.value == selectedValue);
    final currentIndex = index < 0 ? 0 : index;
    final current = options[currentIndex];
    final style = OptionStyle.of(current);
    final emoji = current.emoji == null ? '' : '${current.emoji} ';
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
              Expanded(child: Text(title, style: profileCardTitle)),
              Text(
                '$emoji${TemplateText.textOf(context, current.label)}',
                style: WizType.captionStrong.copyWith(color: style.color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: TemplateText.textOf(context, options[i].label),
                    selected: i == currentIndex,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelect(int.tryParse(options[i].value) ?? options[i].value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        height: 14,
                        decoration: BoxDecoration(
                          color: i <= currentIndex ? style.color : WizColors.inkMeter,
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
