import 'package:appwizard/core/services/onboarding_service.dart';
import 'package:appwizard/core/services/push_topic_service.dart';
import 'package:appwizard/core/services/user_profile_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:appwizard/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Feature-local dependency registration for `onboarding`.
/// Called from core/di/injection_container.dart after core services are registered.
void registerOnboardingDependencies(GetIt sl) {
  if (!sl.isRegistered<OnboardingBloc>()) {
    sl.registerFactory<OnboardingBloc>(
      () => OnboardingBloc(
        repository: sl<OnboardingRepository>(),
        onboardingService: sl<OnboardingService>(),
        logger: sl<AppLogger>(),
        preferences: sl.isRegistered<SharedPreferences>() ? sl<SharedPreferences>() : null,
        profileService: sl.isRegistered<UserProfileService>() ? sl<UserProfileService>() : null,
        pushTopics: sl.isRegistered<PushTopicService>() ? sl<PushTopicService>() : null,
      ),
    );
  }
}
