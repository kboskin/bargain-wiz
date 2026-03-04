import 'package:equatable/equatable.dart';

/// Type of a feedback form field (remotely configurable).
enum FeedbackFormFieldType {
  text,
  textarea,
}

/// Definition of a single field in the feedback form (label, type, required, placeholder from RC).
class FeedbackFormField extends Equatable {
  const FeedbackFormField({
    required this.id,
    required this.label,
    required this.type,
    this.required = false,
    this.placeholder = '',
  });

  final String id;
  final String label;
  final FeedbackFormFieldType type;
  final bool required;
  final String placeholder;

  @override
  List<Object?> get props => [id, label, type, required, placeholder];
}
