import 'package:appwizard/data/models/remote_config/feedback_form_config_model.dart';

/// Remote data source for feedback: form config from RC, submit to backend.
abstract class FeedbackRemoteDataSource {
  /// Gets feedback form configuration from Remote Config (key: feedback_form_config).
  Future<FeedbackFormConfigModel?> getFeedbackFormConfig();

  /// Submits feedback payload to the backend. [values] is field id -> value.
  /// [submitUrl] is the remotely configured backend endpoint.
  Future<void> submitFeedback(Map<String, String> values, String submitUrl);
}
