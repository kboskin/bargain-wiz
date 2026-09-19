import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/icon_resolver.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/wiz/wiz_chip.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/onboarding_text.dart';
import 'package:flutter/material.dart';

/// `select_group` template: several chip groups on one page, each writing its
/// own `answer_key_name`. Answer: `Map<String, dynamic>` of `{key: value}`.
class SelectGroupScreenWidget extends StatelessWidget {
  const SelectGroupScreenWidget({
    required this.model,
    required this.onChanged,
    super.key,
    this.values = const {},
    this.textColor = WizColors.ink,
  });

  final SelectGroupScreenModel model;
  final Map<String, dynamic> values;
  final Color textColor;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnboardingScreenHeader(model: model, textColor: textColor, bottomGap: 18),
          Expanded(
            child: SingleChildScrollView(
              clipBehavior: Clip.none,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var g = 0; g < model.groups.length; g++) ...[
                    if (g > 0) const SizedBox(height: 20),
                    _Group(
                      group: model.groups[g],
                      value: values[model.groups[g].answerKeyName]?.toString(),
                      onPick: (v) => onChanged({...values, model.groups[g].answerKeyName: v}),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
}

class _Group extends StatelessWidget {
  const _Group({required this.group, required this.onPick, this.value});

  final SelectGroup group;
  final String? value;
  final ValueChanged<String> onPick;

  /// The glyph the option configures (`icon: {code, font}`), nothing when it configures none.
  IconData? _iconFor(OnboardingOption option) =>
      option.hasIcon ? IconResolver.resolve(option.iconRaw).icon : null;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TemplateText.textOf(context, group.label).toUpperCase(),
            style: WizType.label,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in group.options)
                WizChip(
                  label: TemplateText.textOf(context, option.label),
                  leading: switch (_iconFor(option)) {
                    final icon? => Icon(icon),
                    null => null,
                  },
                  selected: value != null && value == option.storedValue,
                  onTap: () => onPick(option.storedValue),
                ),
            ],
          ),
        ],
      );
}
