import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/wiz/fade_up.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/core/widgets/wiz/wiz_chip.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/onboarding_text.dart';
import 'package:appwizard/features/shared/data/models/icon_config.dart';
import 'package:flutter/material.dart';

/// `select` template (single choice): option cards with a coloured initial /
/// icon disc, label + subtext, and an ink check when selected.
/// Also serves the retired screens (gender, source, goal, platform…).
class SelectScreenWidget extends StatelessWidget {
  const SelectScreenWidget({
    required this.model,
    required this.onOptionSelected,
    super.key,
    this.selectedValue,
    this.textColor = WizColors.ink,
  });

  final SelectScreenModel model;
  final String? selectedValue;
  final Color textColor;
  final ValueChanged<String> onOptionSelected;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnboardingScreenHeader(model: model, textColor: textColor, bottomGap: 18),
          Expanded(
            child: ListView.separated(
              clipBehavior: Clip.none,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: model.options.length,
              separatorBuilder: (_, __) => const SizedBox(height: WizSpacing.stack),
              itemBuilder: (context, i) {
                final option = model.options[i];
                final value = option.storedValue;
                final label = TemplateText.textOf(context, option.label);
                final iconConfig = option.hasIcon ? IconConfig.fromJson(option.iconRaw) : null;
                return FadeUp(
                  delay: WizMotion.listStagger * i,
                  child: _OptionCard(
                    label: label,
                    subtext: TemplateText.textOf(context, option.subtext),
                    color: wizHexColor(option.colorHex),
                    icon: iconConfig?.iconData,
                    isFontAwesome: iconConfig?.isFontAwesome ?? false,
                    selected: selectedValue != null && selectedValue == value,
                    onTap: () => onOptionSelected(value),
                  ),
                );
              },
            ),
          ),
        ],
      );
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.label,
    required this.subtext,
    required this.selected,
    required this.onTap,
    this.color,
    this.icon,
    this.isFontAwesome = false,
  });

  final String label;
  final String subtext;
  final Color? color;
  final IconData? icon;
  final bool isFontAwesome;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final disc = color ?? WizColors.inkMeter;
    final onDisc = color == null ? WizColors.ink : WizChip.contrastOn(disc);
    final initial = label.isEmpty ? '' : label.characters.first.toUpperCase();

    return WizPressable(
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: disc, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: icon != null
                  ? Icon(icon, size: isFontAwesome ? 18 : 20, color: onDisc)
                  : Text(initial, style: WizType.optionInitial.copyWith(color: onDisc, height: 1)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: WizType.optionLabel),
                  if (subtext.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtext, style: WizType.caption.copyWith(height: 1.35)),
                  ],
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: selected
                  ? Container(
                      key: const ValueKey('check'),
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(left: 14),
                      decoration: const BoxDecoration(color: WizColors.ink, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const WizCheckMark(),
                    )
                  : const SizedBox(key: ValueKey('none'), width: 0, height: 24),
            ),
          ],
        ),
      ),
    );
  }
}
