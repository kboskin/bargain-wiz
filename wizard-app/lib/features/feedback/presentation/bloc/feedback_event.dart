import 'package:appwizard/features/shared/presentation/bloc/base_bloc.dart';

/// Feedback flow events.
abstract class FeedbackEvent extends BaseEvent {
  const FeedbackEvent();
}

/// Load feedback form config from Remote Config.
class LoadFeedbackFormRequested extends FeedbackEvent {
  const LoadFeedbackFormRequested();
}

/// Submit user feedback (field id -> value) to backend.
class FeedbackSubmitted extends FeedbackEvent {
  const FeedbackSubmitted(this.values);

  final Map<String, String> values;

  @override
  List<Object?> get props => [values];
}
