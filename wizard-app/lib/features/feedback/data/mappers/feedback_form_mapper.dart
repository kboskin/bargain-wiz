import 'package:appwizard/features/feedback/data/models/feedback_form_config_model.dart';
import 'package:appwizard/features/feedback/domain/entities/feedback_form_config.dart';
import 'package:appwizard/features/feedback/domain/entities/feedback_form_field.dart';

/// Maps feedback form config from data layer to domain entities.
class FeedbackFormMapper {
  FeedbackFormConfig toEntity(FeedbackFormConfigModel model) {
    return FeedbackFormConfig(
      title: model.title,
      description: model.description,
      submitButtonText: model.submitButtonText,
      fields: model.fields.map(_fieldToEntity).toList(),
      submitUrl: model.submitUrl,
      titleHighlightWords: model.titleHighlightWords,
      titleHighlightColor: model.titleHighlightColor,
    );
  }

  FeedbackFormField _fieldToEntity(FeedbackFormFieldModel model) {
    return FeedbackFormField(
      id: model.id,
      label: model.label,
      type: model.type == 'textarea'
          ? FeedbackFormFieldType.textarea
          : FeedbackFormFieldType.text,
      required: model.required,
      placeholder: model.placeholder,
    );
  }
}
