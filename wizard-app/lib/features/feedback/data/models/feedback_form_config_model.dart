/// Remote config model for the feedback form (key `feedback_form_config`).
///
/// Copy values are kept raw (`String` or `{en, es}` map) and resolved at render
/// time with `TemplateText.textOf`, so both legacy plain-string configs and
/// multilocale configs parse.
class FeedbackFormConfigModel {
  FeedbackFormConfigModel({
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

  /// `String` or multilocale `Map`.
  final dynamic title;
  final dynamic description;
  final dynamic submitButtonText;
  final List<FeedbackFormFieldModel> fields;
  final String submitUrl;
  final dynamic titleHighlightWords;
  final String? titleHighlightColor;
  final dynamic successTitle;
  final dynamic successBody;
  final dynamic successCta;
  final dynamic validationMessage;

  factory FeedbackFormConfigModel.fromJson(Map<String, dynamic> json) {
    final fieldsList = json['fields'] as List<dynamic>? ?? [];
    return FeedbackFormConfigModel(
      title: text(json['title']),
      description: text(json['description']),
      submitButtonText: text(json['submit_button_text']),
      submitUrl: json['submit_url'] as String? ?? '',
      fields: fieldsList
          .whereType<Map>()
          .map((m) => FeedbackFormFieldModel.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      titleHighlightWords: json['title_highlight_words'],
      titleHighlightColor: json['title_highlight_color'] as String?,
      successTitle: text(json['success_title']),
      successBody: text(json['success_body']),
      successCta: text(json['success_cta']),
      validationMessage: text(json['validation_message']),
    );
  }

  /// Normalizes a copy value: non-empty `String` or `Map` pass through, anything else → `null`.
  static dynamic text(dynamic value) {
    if (value is String) return value.isEmpty ? null : value;
    if (value is Map) return value.isEmpty ? null : Map<String, dynamic>.from(value);
    return null;
  }
}

class FeedbackFormFieldModel {
  FeedbackFormFieldModel({
    required this.id,
    required this.label,
    required this.type,
    this.required = false,
    this.placeholder,
  });

  final String id;
  /// `String` or multilocale `Map`.
  final dynamic label;
  final String type; // "text" | "textarea"
  final bool required;
  final dynamic placeholder;

  factory FeedbackFormFieldModel.fromJson(Map<String, dynamic> json) => FeedbackFormFieldModel(
        id: json['id'] as String? ?? '',
        label: FeedbackFormConfigModel.text(json['label']),
        type: (json['type'] as String?)?.toLowerCase() ?? 'text',
        required: json['required'] as bool? ?? false,
        placeholder: FeedbackFormConfigModel.text(json['placeholder']),
      );
}
