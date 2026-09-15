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

/// Config could not be loaded.
class FeedbackError extends FeedbackState {
  const FeedbackError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Any state that has a usable [config] (form shown or just submitted).
abstract class FeedbackFormReady extends FeedbackState {
  const FeedbackFormReady(this.config);

  final FeedbackFormConfig config;

  @override
  List<Object?> get props => [config];
}

class FeedbackLoaded extends FeedbackFormReady {
  const FeedbackLoaded(super.config);
}

class FeedbackSubmitting extends FeedbackFormReady {
  const FeedbackSubmitting(super.config);
}

/// Submit failed; the form stays visible with the previous values.
class FeedbackSubmitFailure extends FeedbackFormReady {
  const FeedbackSubmitFailure(super.config, this.message);

  final String message;

  @override
  List<Object?> get props => [config, message];
}

class FeedbackSubmitSuccess extends FeedbackFormReady {
  const FeedbackSubmitSuccess(super.config);
}
