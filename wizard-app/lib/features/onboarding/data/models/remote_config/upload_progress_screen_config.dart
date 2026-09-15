import 'package:appwizard/features/shared/data/models/multilocale_text.dart';
import 'package:appwizard/features/shared/data/models/validatable_entity.dart';
import 'package:json_annotation/json_annotation.dart';

part 'upload_progress_screen_config.g.dart';

/// Config for the "upload user data" progress screen.
/// Data comes from Remote Config via the data_upload entry in [onboarding_screens]
/// (top-level [visual] + [metadata]: texts, text_interval_seconds, progress_ramp_seconds,
/// done_text, done_hold_seconds, progress_gradient).
@JsonSerializable()
class UploadProgressScreenConfig extends ValidatableEntity {
  UploadProgressScreenConfig({
    required this.lottieAsset,
    required this.texts,
    this.textIntervalSeconds = 2.5,
    this.progressRampSeconds = 5.0,
    this.doneText,
    this.doneHoldSeconds = 1.4,
    this.progressGradient,
  });

  factory UploadProgressScreenConfig.fromJson(Map<String, dynamic> json) =>
      _$UploadProgressScreenConfigFromJson(json);

  /// Lottie asset path (e.g. assets/lottie/pot.json)
  @JsonKey(name: 'lottie_asset')
  final String lottieAsset;

  /// List of multilocale texts to cycle through while upload is in progress.
  /// May contain `{platform}` / `{push}` placeholders.
  @JsonKey(fromJson: _textsFromJson)
  final List<dynamic> texts;

  /// Interval in seconds between switching to the next text
  @JsonKey(name: 'text_interval_seconds')
  final double textIntervalSeconds;

  /// Duration in seconds of the time-based ramp from 0 to 100%. Default 5.
  @JsonKey(name: 'progress_ramp_seconds')
  final double? progressRampSeconds;

  /// Text shown when progress reaches 100% (e.g. "Ready. Let's go get those deals.").
  @JsonKey(name: 'done_text', fromJson: _multilocaleFromJson)
  final dynamic doneText;

  /// How long the done text is held before the flow completes. Default 1.4 s.
  @JsonKey(name: 'done_hold_seconds')
  final double doneHoldSeconds;

  /// Progress bar gradient colors (hex strings), e.g. ["#7B5EA7", "#4ECDC4"].
  @JsonKey(name: 'progress_gradient')
  final List<String>? progressGradient;

  static List<dynamic> _textsFromJson(dynamic json) {
    if (json == null) return [];
    if (json is! List) return [];
    return json
        .map((e) => e != null ? MultilocaleText.fromJson(e) : null)
        .whereType<MultilocaleText>()
        .toList();
  }

  static dynamic _multilocaleFromJson(dynamic json) =>
      json != null ? MultilocaleText.fromJson(json) : null;

  Map<String, dynamic> toJson() => _$UploadProgressScreenConfigToJson(this);

  @override
  void validate() {
    super.validate();
    if (lottieAsset.isEmpty) {
      throw const FormatException('UploadProgressScreenConfig.lottieAsset cannot be empty');
    }
    if (textIntervalSeconds <= 0) {
      throw const FormatException(
          'UploadProgressScreenConfig.textIntervalSeconds must be positive');
    }
  }
}
