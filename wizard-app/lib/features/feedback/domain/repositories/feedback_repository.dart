import 'package:dartz/dartz.dart';

import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/features/feedback/domain/entities/feedback_form_config.dart';

/// Repository for feedback form config (from Remote Config) and submitting feedback to backend.
abstract class FeedbackRepository {
  /// Returns the feedback form configuration (fields, labels, etc.). Remotely configurable.
  Future<Either<Failure, FeedbackFormConfig>> getFeedbackFormConfig();

  /// Submits user feedback (map of field id -> value) to the backend.
  /// [submitUrl] is from [FeedbackFormConfig.submitUrl] (remotely configurable).
  Future<Either<Failure, void>> submitFeedback(
    Map<String, String> values,
    String submitUrl,
  );
}
