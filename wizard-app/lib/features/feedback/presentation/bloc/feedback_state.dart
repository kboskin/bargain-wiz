import 'package:appwizard/features/feedback/domain/entities/feedback_form_config.dart';
import 'package:appwizard/features/shared/presentation/bloc/base_bloc.dart';

/// Feedback flow states.
abstract class FeedbackState extends BaseState {
  const FeedbackState();
}

class FeedbackInitial extends FeedbackState {
  const FeedbackInitial();
}

class FeedbackLoading extends FeedbackState {
  const FeedbackLoading();
}

class FeedbackLoaded extends FeedbackState {
  const FeedbackLoaded(this.config);

  final FeedbackFormConfig config;

  @override
  List<Object?> get props => [config];
}

class FeedbackSubmitting extends FeedbackState {
  const FeedbackSubmitting();
}

class FeedbackSubmitSuccess extends FeedbackState {
  const FeedbackSubmitSuccess();
}

class FeedbackError extends FeedbackState {
  const FeedbackError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
