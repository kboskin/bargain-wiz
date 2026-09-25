import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/wiz/wiz_chip.dart';
import 'package:appwizard/core/widgets/wiz/wiz_mascot.dart';
import 'package:appwizard/features/pro_deal_closer/presentation/widgets/pro_message_tile.dart';
import 'package:appwizard/features/shared/data/models/deal_objective.dart';
import 'package:flutter/material.dart';

/// Under the greeting: the wizard asks what the deal is for ([title]) and offers one chip per
/// configured objective. An objective is its text, so the chip that is picked is the one whose
/// [DealObjective.prompt] equals [selected]. Tapping picks one — tapping it again, none — until
/// the chat exists; after that [onSelect] is null and only the picked objective stays, as a
/// record of what the chat was started for. Nothing is shown when there is nothing to pick or
/// to record.
class DealObjectivePicker extends StatelessWidget {
  const DealObjectivePicker({
    required this.title,
    required this.objectives,
    super.key,
    this.selected,
    this.onSelect,
  });

  final String title;
  final List<DealObjective> objectives;
  final String? selected;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(final BuildContext context) {
    final onSelect = this.onSelect;
    // An objective with no text has nothing to tell the model, so it is not offered.
    final offered = objectives.where((final o) => (o.prompt ?? '').trim().isNotEmpty);
    final shown = (onSelect == null ? offered.where((final o) => o.prompt == selected) : offered).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    final maxWidth = MediaQuery.sizeOf(context).width * 0.92;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const WizAvatar(),
            const SizedBox(width: 8),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth - kProWizardIndent),
                child: WizardBubble(text: title),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: kProWizardIndent),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final objective in shown)
                WizChip(
                  compact: true,
                  label: _label(context, objective),
                  selected: objective.prompt == selected,
                  onTap: onSelect == null ? null : () => onSelect(objective.prompt!),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _label(final BuildContext context, final DealObjective objective) {
    final text = TemplateText.textOf(context, objective.label, fallback: objective.prompt ?? '');
    final emoji = objective.emoji?.trim() ?? '';
    return emoji.isEmpty ? text : '$emoji $text';
  }
}
