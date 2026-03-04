import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_screen_config.dart';

/// Maps [OnboardingScreenType] enum to/from string (e.g. stored answers, API).
class OnboardingScreenTypeMapper {
  OnboardingScreenType toEntity(String? value) {
    if (value == null || value.isEmpty) return OnboardingScreenType.engagement;
    return OnboardingScreenType.fromString(value);
  }

  String toModel(OnboardingScreenType type) {
    return type.name;
  }
}
