import 'package:equatable/equatable.dart';

import 'package:appwizard/features/feedback/domain/entities/feedback_form_field.dart';

/// Remotely configurable feedback form (title, description, submit button text, fields, backend URL).
class FeedbackFormConfig extends Equatable {
  const FeedbackFormConfig({
    required this.title,
    required this.description,
    required this.submitButtonText,
    required this.fields,
    this.submitUrl = '',
    this.titleHighlightWords,
    this.titleHighlightColor,
  });

  final String title;
  final String description;
  final String submitButtonText;
  final List<FeedbackFormField> fields;
  final String submitUrl;
  /// Optional highlight config for title (same as onboarding); e.g. {"feedback": "#4ECDC4"}.
  final dynamic titleHighlightWords;
  final String? titleHighlightColor;

  @override
  List<Object?> get props => [title, description, submitButtonText, fields, submitUrl, titleHighlightWords, titleHighlightColor];
}
