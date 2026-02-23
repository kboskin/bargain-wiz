import 'package:appwizard/data/models/multilocale_text.dart';
import 'package:appwizard/data/models/remote_config/validatable_entity.dart';
import 'package:json_annotation/json_annotation.dart';

part 'upload_progress_screen_config.g.dart';

/// Config for the "upload user data" progress screen.
/// Data comes from Remote Config via the data_upload entry in [onboarding_screens]
/// (top-level [visual] + [metadata]: texts, text_interval_seconds, progress_ramp_seconds).
@JsonSerializable()
class UploadProgressScreenConfig extends ValidatableEntity {
  /// Lottie asset path (e.g. assets/lottie/upload_animation.json)
  @JsonKey(name: 'lottie_asset')
  final String lottieAsset;

  /// List of multilocale texts to cycle through while upload is in progress
  @JsonKey(fromJson: _textsFromJson)
  final List<dynamic> texts;

  /// Interval in seconds between switching to the next text
  @JsonKey(name: 'text_interval_seconds')
  final double textIntervalSeconds;

  /// Duration in seconds to ramp progress linearly from 0 to ~90%. Default 5. When backend responds, progress goes to 100%.
  @JsonKey(name: 'progress_ramp_seconds')
  final double? progressRampSeconds;

  UploadProgressScreenConfig({
    required this.lottieAsset,
    required this.texts,
    this.textIntervalSeconds = 2.5,
    this.progressRampSeconds = 5.0,
  });

  factory UploadProgressScreenConfig.fromJson(Map<String, dynamic> json) =>
      _$UploadProgressScreenConfigFromJson(json);

  static List<dynamic> _textsFromJson(dynamic json) {
    if (json == null) return [];
    if (json is! List) return [];
    return json
        .map((e) => e != null ? MultilocaleText.fromJson(e) : null)
        .whereType<MultilocaleText>()
        .toList();
  }

  Map<String, dynamic> toJson() => _$UploadProgressScreenConfigToJson(this);

  @override
  void validate() {
    super.validate();
    if (lottieAsset.isEmpty) {
      throw FormatException('UploadProgressScreenConfig.lottieAsset cannot be empty');
    }
    if (textIntervalSeconds <= 0) {
      throw FormatException(
          'UploadProgressScreenConfig.textIntervalSeconds must be positive');
    }
  }
}
