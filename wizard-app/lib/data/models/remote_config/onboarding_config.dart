import 'package:appwizard/data/models/remote_config/gradient_background_config.dart';
import 'package:json_annotation/json_annotation.dart';

part 'onboarding_config.g.dart';

/// Remote config for the onboarding flow (e.g. background).
/// RC key: [onboarding_config].
@JsonSerializable()
class OnboardingConfig {
  OnboardingConfig({this.background});

  /// Gradient background for onboarding screens.
  @JsonKey(name: 'background')
  final GradientBackgroundConfig? background;

  factory OnboardingConfig.fromJson(Map<String, dynamic> json) =>
      _$OnboardingConfigFromJson(json);

  Map<String, dynamic> toJson() => _$OnboardingConfigToJson(this);
}
