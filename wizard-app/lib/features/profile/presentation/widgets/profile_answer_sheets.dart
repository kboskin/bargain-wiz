import 'package:flutter/material.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/core/widgets/wiz/wiz_chip.dart';
import 'package:appwizard/core/widgets/wiz/wiz_sheet.dart';
import 'package:appwizard/core/widgets/wiz/wiz_text_field.dart';
import 'package:appwizard/features/profile/domain/profile_fields.dart';

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
        scrollable: true,
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

/// Bottom sheet to pick several [ProfileOption]s: tick rows (the labels are sentences, not
/// chip-sized) plus a Save button that stays disabled below [minSelected]. Reports the
/// picks in tap order, like the onboarding `multi_select` template.
Future<void> showProfileMultiSelectSheet(
  BuildContext context, {
  required String title,
  required List<ProfileOption> options,
  required List<String> selected,
  required ValueChanged<List<String>> onSave,
  int minSelected = 0,
}) =>
    WizSheet.show<void>(
      context,
      builder: (sheetContext) => _MultiSelectSheet(
        title: title,
        options: options,
        selected: selected,
        minSelected: minSelected,
        onSave: onSave,
      ),
    );

class _MultiSelectSheet extends StatefulWidget {
  const _MultiSelectSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.minSelected,
    required this.onSave,
  });

  final String title;
  final List<ProfileOption> options;
  final List<String> selected;
  final int minSelected;
  final ValueChanged<List<String>> onSave;

  @override
  State<_MultiSelectSheet> createState() => _MultiSelectSheetState();
}

class _MultiSelectSheetState extends State<_MultiSelectSheet> {
  late final List<String> _picked = List<String>.from(widget.selected);

  void _toggle(String value) {
    setState(() {
      if (!_picked.remove(value)) _picked.add(value);
    });
  }

  @override
  Widget build(BuildContext context) => WizSheet(
        title: widget.title,
        onClose: () => Navigator.of(context).pop(),
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final o in widget.options) ...[
              _TickRow(
                label: TemplateText.textOf(context, o.label, fallback: o.value),
                selected: _picked.contains(o.value),
                onTap: () => _toggle(o.value),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            WizPrimaryButton(
              label: 'Save',
              onPressed: _picked.length < widget.minSelected
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      widget.onSave(List<String>.from(_picked));
                    },
            ),
          ],
        ),
      );
}

class _TickRow extends StatelessWidget {
  const _TickRow({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => WizPressable(
        onTap: onTap,
        scale: 0.99,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.white : WizColors.frosted,
            borderRadius: BorderRadius.circular(WizRadii.card),
            border: Border.all(
              color: selected ? WizColors.ink : WizColors.frostedBorder,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: selected ? WizColors.ink : Colors.transparent,
                  borderRadius: BorderRadius.circular(WizRadii.checkbox),
                  border: Border.all(
                    color: selected ? WizColors.ink : WizColors.borderStrong,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: WizType.bodySm)),
            ],
          ),
        ),
      );
}

/// Bottom sheet with a single text field (referral code); saves the trimmed value.
Future<void> showProfileTextSheet(
  BuildContext context, {
  required String title,
  required String? value,
  required ValueChanged<String> onSave,
  String? hintText,
  bool uppercase = false,
}) =>
    WizSheet.show<void>(
      context,
      builder: (sheetContext) => _TextSheet(
        title: title,
        value: value,
        hintText: hintText,
        uppercase: uppercase,
        onSave: onSave,
      ),
    );

class _TextSheet extends StatefulWidget {
  const _TextSheet({
    required this.title,
    required this.value,
    required this.hintText,
    required this.uppercase,
    required this.onSave,
  });

  final String title;
  final String? value;
  final String? hintText;
  final bool uppercase;
  final ValueChanged<String> onSave;

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  late final TextEditingController _controller = TextEditingController(text: widget.value ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    Navigator.of(context).pop();
    widget.onSave(widget.uppercase ? text.toUpperCase() : text);
  }

  @override
  Widget build(BuildContext context) => WizSheet(
        title: widget.title,
        onClose: () => Navigator.of(context).pop(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WizTextField(
              controller: _controller,
              height: 56,
              radius: WizRadii.card,
              hintText: widget.hintText,
              style: widget.uppercase ? WizType.code : null,
              textCapitalization:
                  widget.uppercase ? TextCapitalization.characters : TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            WizPrimaryButton(label: 'Save', onPressed: _save),
          ],
        ),
      );
}
