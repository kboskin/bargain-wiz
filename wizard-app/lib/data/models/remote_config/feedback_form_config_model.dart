/// Remote config model for feedback form (title, description, submit button, fields).
/// All fields are remotely configurable via key [feedback_form_config].
class FeedbackFormConfigModel {
  FeedbackFormConfigModel({
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
  final List<FeedbackFormFieldModel> fields;
  final String submitUrl;
  final dynamic titleHighlightWords;
  final String? titleHighlightColor;

  factory FeedbackFormConfigModel.fromJson(Map<String, dynamic> json) {
    final fieldsList = json['fields'] as List<dynamic>? ?? [];
    return FeedbackFormConfigModel(
      title: json['title'] as String? ?? 'Feedback',
      description: json['description'] as String? ?? '',
      submitButtonText: json['submit_button_text'] as String? ?? 'Send',
      submitUrl: json['submit_url'] as String? ?? '',
      fields: fieldsList
          .whereType<Map<String, dynamic>>()
          .map(FeedbackFormFieldModel.fromJson)
          .toList(),
      titleHighlightWords: json['title_highlight_words'],
      titleHighlightColor: json['title_highlight_color'] as String?,
    );
  }
}

class FeedbackFormFieldModel {
  FeedbackFormFieldModel({
    required this.id,
    required this.label,
    required this.type,
    this.required = false,
    this.placeholder = '',
  });

  final String id;
  final String label;
  final String type; // "text" | "textarea"
  final bool required;
  final String placeholder;

  factory FeedbackFormFieldModel.fromJson(Map<String, dynamic> json) {
    return FeedbackFormFieldModel(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      type: (json['type'] as String?)?.toLowerCase() ?? 'text',
      required: json['required'] as bool? ?? false,
      placeholder: json['placeholder'] as String? ?? '',
    );
  }
}
