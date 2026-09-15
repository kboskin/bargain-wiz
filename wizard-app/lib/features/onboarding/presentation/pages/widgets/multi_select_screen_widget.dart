import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/wiz/fade_up.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/onboarding_text.dart';
import 'package:flutter/material.dart';

/// `multi_select` template: checkbox rows + reassurance panel once ≥1 is picked.
/// Answer: ordered `List<String>` of option values (first pick = primary hurdle).
class MultiSelectScreenWidget extends StatelessWidget {
  const MultiSelectScreenWidget({
    required this.model,
    required this.onChanged,
    super.key,
    this.selectedValues = const [],
    this.textColor = WizColors.ink,
  });

  final MultiSelectScreenModel model;
  final List<String> selectedValues;
  final Color textColor;
  final ValueChanged<List<String>> onChanged;

  void _toggle(String value) {
    final next = List<String>.from(selectedValues);
    if (!next.remove(value)) next.add(value);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final count = selectedValues.length;
    final reassurance = model.reassuranceFor(count);
    final reassuranceText = reassurance == null ? '' : TemplateText.textOf(context, reassurance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnboardingScreenHeader(model: model, textColor: textColor),
        Expanded(
          child: ListView.separated(
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: model.options.length,
            separatorBuilder: (_, __) => const SizedBox(height: WizSpacing.stack),
            itemBuilder: (context, i) {
              final option = model.options[i];
              final value = option.storedValue;
              return FadeUp(
                delay: WizMotion.listStagger * i,
                child: _CheckRow(
                  label: TemplateText.textOf(context, option.label),
                  dotColor: wizHexColor(option.colorHex) ?? WizColors.purple,
                  selected: selectedValues.contains(value),
                  onTap: () => _toggle(value),
                ),
              );
            },
          ),
        ),
        if (count > 0 && reassuranceText.isNotEmpty)
          FadeUp(
            key: ValueKey<int>(reassurance.hashCode),
            duration: const Duration(milliseconds: 300),
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: WizColors.tealHint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                reassuranceText,
                style: WizType.captionMedium.copyWith(color: WizColors.tealInk),
              ),
            ),
          ),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.dotColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color dotColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => WizPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? Colors.white : WizColors.frosted,
            borderRadius: BorderRadius.circular(WizRadii.card),
            border: Border.all(
              color: selected ? WizColors.ink : WizColors.frostedBorder,
              width: 1.5,
            ),
            boxShadow: WizShadows.cardSoft,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: selected ? WizColors.ink : Colors.transparent,
                  borderRadius: BorderRadius.circular(WizRadii.checkbox),
                  border: Border.all(
                    color: selected ? WizColors.ink : WizColors.borderStrong,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: selected ? const WizCheckMark() : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: WizType.bodyMdStrong.copyWith(height: 1.35),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
            ],
          ),
        ),
      );
}
