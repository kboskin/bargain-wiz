import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/features/feedback/domain/entities/feedback_form_field.dart';

/// Remotely configurable feedback form: copy (String or multilocale map, resolved
/// with the `*Of(context)` getters), fields, backend URL and success-state copy.
class FeedbackFormConfig extends Equatable {
  const FeedbackFormConfig({
    required this.title,
    required this.description,
    required this.submitButtonText,
    required this.fields,
    this.submitUrl = '',
    this.titleHighlightWords,
    this.titleHighlightColor,
    this.successTitle,
    this.successBody,
    this.successCta,
    this.validationMessage,
  });

  static const String defaultTitle = 'Send feedback';
  static const String defaultSubmit = 'Send';
  static const String defaultSuccessTitle = 'Thank you';
  static const String defaultSuccessBody = 'Your note is with the wizards.';
  static const String defaultSuccessCta = 'Back to deals';
  static const String defaultValidationMessage = 'Please add a message before sending.';

  final dynamic title;
  final dynamic description;
  final dynamic submitButtonText;
  final List<FeedbackFormField> fields;
  final String submitUrl;
  /// Optional highlight config for the title (same shape as onboarding); e.g. {"feedback": "#4ECDC4"}.
  final dynamic titleHighlightWords;
  final String? titleHighlightColor;
  final dynamic successTitle;
  final dynamic successBody;
  final dynamic successCta;
  final dynamic validationMessage;

  String titleOf(BuildContext c) => TemplateText.textOf(c, title, fallback: defaultTitle);
  String descriptionOf(BuildContext c) => TemplateText.textOf(c, description);
  String submitButtonTextOf(BuildContext c) =>
      TemplateText.textOf(c, submitButtonText, fallback: defaultSubmit);
  String successTitleOf(BuildContext c) =>
      TemplateText.textOf(c, successTitle, fallback: defaultSuccessTitle);
  String successBodyOf(BuildContext c) =>
      TemplateText.textOf(c, successBody, fallback: defaultSuccessBody);
  String successCtaOf(BuildContext c) => TemplateText.textOf(c, successCta, fallback: defaultSuccessCta);
  String validationMessageOf(BuildContext c) =>
      TemplateText.textOf(c, validationMessage, fallback: defaultValidationMessage);

  @override
  List<Object?> get props => [
        title,
        description,
        submitButtonText,
        fields,
        submitUrl,
        titleHighlightWords,
        titleHighlightColor,
        successTitle,
        successBody,
        successCta,
        validationMessage,
      ];
}
