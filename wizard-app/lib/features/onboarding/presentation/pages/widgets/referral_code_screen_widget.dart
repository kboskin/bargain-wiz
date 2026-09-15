import 'dart:async';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/wiz/wiz_text_field.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/onboarding_text.dart';
import 'package:flutter/material.dart';

/// `referral_code` template: optional code input (56h, radius 18, uppercase).
class ReferralCodeScreenWidget extends StatefulWidget {
  const ReferralCodeScreenWidget({
    required this.model,
    required this.onValueChanged,
    super.key,
    this.selectedValue,
    this.textColor = WizColors.ink,
  });

  final ReferralCodeScreenModel model;
  final String? selectedValue;
  final Color textColor;
  final ValueChanged<String> onValueChanged;

  @override
  State<ReferralCodeScreenWidget> createState() => _ReferralCodeScreenWidgetState();
}

class _ReferralCodeScreenWidgetState extends State<ReferralCodeScreenWidget> {
  late final TextEditingController _controller = TextEditingController(text: widget.selectedValue ?? '');
  Timer? _debounce;

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) widget.onValueChanged(text.trim().toUpperCase());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = TemplateText.textOf(context, widget.model.placeholder, fallback: 'Enter code');
    return OnboardingScrollFill(
      children: [
        OnboardingScreenHeader(
          model: widget.model,
          textColor: widget.textColor,
          titleHighlightWeight: FontWeight.w500,
          bottomGap: 22,
        ),
        WizTextField(
          controller: _controller,
          height: 56,
          radius: WizRadii.card,
          hintText: placeholder,
          style: WizType.code,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          onChanged: _onChanged,
          onSubmitted: (v) => widget.onValueChanged(v.trim().toUpperCase()),
        ),
        const Expanded(child: SizedBox.shrink()),
      ],
    );
  }
}
