import 'package:appwizard/features/onboarding/data/models/remote_config/gradient_background_config.dart';
import 'package:json_annotation/json_annotation.dart';

part 'onboarding_config.g.dart';

/// Remote config for the onboarding flow (e.g. background, text color).
/// RC key: [onboarding_config].
@JsonSerializable()
class OnboardingConfig {
  OnboardingConfig({this.background, this.textColor});

  /// Gradient background for onboarding screens.
  @JsonKey(name: 'background')
  final GradientBackgroundConfig? background;

  /// Base text color for title/description (hex string). Defaults to black when null.
  @JsonKey(name: 'text_color')
  final String? textColor;

  factory OnboardingConfig.fromJson(Map<String, dynamic> json) =>
      _$OnboardingConfigFromJson(json);

  Map<String, dynamic> toJson() => _$OnboardingConfigToJson(this);
}
