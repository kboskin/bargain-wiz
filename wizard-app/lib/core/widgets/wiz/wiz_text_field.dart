import 'package:flutter/material.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';

/// White rounded input (radius 16, 1.5px border, Figtree 15). Error border red.
class WizTextField extends StatelessWidget {
  const WizTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.height,
    this.radius = WizRadii.field,
    this.minLines,
    this.maxLines = 1,
    this.error = false,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.prefix,
    this.suffix,
    this.style,
    this.textCapitalization = TextCapitalization.none,
    this.contentPadding,
    this.autofocus = false,
    this.fill = Colors.white,
    this.borderColor = WizColors.border,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final double? height;
  final double radius;
  final int? minLines;
  final int? maxLines;
  final bool error;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? prefix;
  final Widget? suffix;
  final TextStyle? style;
  final TextCapitalization textCapitalization;
  final EdgeInsets? contentPadding;
  final bool autofocus;
  final Color fill;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: error ? WizColors.error : borderColor, width: 1.5),
    );
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      minLines: minLines,
      maxLines: maxLines,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      style: style ?? WizType.fieldText,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: (style ?? WizType.fieldText).copyWith(color: WizColors.textTertiary),
        filled: true,
        fillColor: fill,
        isDense: true,
        prefixIcon: prefix,
        suffixIcon: suffix,
        contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: error ? WizColors.error : WizColors.ink, width: 1.5),
        ),
        errorBorder: border,
        focusedErrorBorder: border,
      ),
    );
    if (height != null) return SizedBox(height: height, child: field);
    return field;
  }
}
