import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import 'package:appwizard/core/utils/template_text.dart';

/// Type of a feedback form field (remotely configurable).
enum FeedbackFormFieldType {
  text,
  textarea,
}

/// Definition of a single field in the feedback form. [label] and [placeholder]
/// are `String` or multilocale maps; resolve with [labelOf] / [placeholderOf].
class FeedbackFormField extends Equatable {
  const FeedbackFormField({
    required this.id,
    required this.label,
    required this.type,
    this.required = false,
    this.placeholder,
  });

  final String id;
  final dynamic label;
  final FeedbackFormFieldType type;
  final bool required;
  final dynamic placeholder;

  String labelOf(BuildContext context) => TemplateText.textOf(context, label);
  String placeholderOf(BuildContext context) => TemplateText.textOf(context, placeholder);

  @override
  List<Object?> get props => [id, label, type, required, placeholder];
}
