import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:appwizard/core/services/auth_service.dart';
import 'package:appwizard/core/services/firebase_service.dart';
import 'package:appwizard/core/services/onboarding_service.dart';
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/services/analytics_service.dart';
import 'package:appwizard/core/routing/app_router.dart';
import 'package:appwizard/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:appwizard/core/services/subscription/payment_provider.dart';
import 'package:appwizard/core/services/subscription/iap_payment_provider.dart';
import 'package:appwizard/core/services/subscription/stripe_payment_provider.dart';
import 'package:appwizard/core/services/subscription/subscription_checker_service.dart';
import 'package:appwizard/core/config/app_config.dart';
import 'package:appwizard/features/subscription/data/datasources/subscription_in_memory_datasource.dart';
import 'package:appwizard/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:appwizard/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:appwizard/features/subscription/presentation/bloc/subscription_bloc.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/core/utils/asset_path_helper.dart';
import 'package:appwizard/core/utils/color_helper.dart';
import 'package:appwizard/features/onboarding/data/datasources/onboarding_local_datasource.dart';
import 'package:appwizard/features/express_dealmaker/data/datasources/express_dealmaker_remote_datasource.dart';
import 'package:appwizard/features/conversation/data/datasources/conversations_api.dart';
import 'package:appwizard/features/conversation/data/datasources/conversations_stream.dart';
import 'package:appwizard/features/conversation/data/datasources/fake_conversations_backend.dart';
import 'package:appwizard/features/onboarding/data/mappers/onboarding_data_mapper.dart';
import 'package:appwizard/features/onboarding/data/mappers/onboarding_screen_type_mapper.dart';
import 'package:appwizard/features/express_dealmaker/data/mappers/express_dealmaker_mapper.dart';
import 'package:appwizard/features/shared/data/network/network_info_impl.dart';
import 'package:appwizard/features/onboarding/data/repositories/onboarding_repository_impl.dart';
import 'package:appwizard/features/express_dealmaker/data/repositories/express_dealmaker_repository_impl.dart';
import 'package:appwizard/features/conversation/data/repositories/conversation_repository_impl.dart';
import 'package:appwizard/features/feedback/data/repositories/feedback_repository_impl.dart';
import 'package:appwizard/features/lines_that_land/data/repositories/lines_that_land_repository_impl.dart';
import 'package:appwizard/features/feedback/data/datasources/feedback_remote_datasource.dart';
import 'package:appwizard/features/feedback/data/datasources/feedback_remote_datasource_impl.dart';
import 'package:appwizard/features/lines_that_land/data/datasources/lines_that_land_api_datasource.dart';
import 'package:appwizard/features/lines_that_land/data/datasources/lines_that_land_local_cache.dart';
import 'package:appwizard/features/feedback/data/mappers/feedback_form_mapper.dart';
import 'package:appwizard/features/lines_that_land/data/mappers/lines_that_land_mapper.dart';
import 'package:appwizard/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:appwizard/features/express_dealmaker/domain/repositories/express_dealmaker_repository.dart';
import 'package:appwizard/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:appwizard/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:appwizard/features/lines_that_land/domain/repositories/lines_that_land_repository.dart';
import 'package:appwizard/features/feedback/presentation/bloc/feedback_bloc.dart';
import 'package:appwizard/features/lines_that_land/presentation/bloc/lines_that_land_bloc.dart';

import 'package:appwizard/core/network/cloud_functions_client.dart';
import 'package:appwizard/core/services/profile_sync_service.dart';
import 'package:appwizard/core/utils/screenshot_encoder.dart';
import 'package:appwizard/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:appwizard/features/express_dealmaker/data/datasources/cloud_express_dealmaker_remote_datasource.dart';
import 'package:appwizard/core/network/network_info.dart';
import 'package:appwizard/core/services/feature_gate_service.dart';
import 'package:appwizard/core/services/user_profile_service.dart';
import 'package:appwizard/features/express_dealmaker/di.dart';
import 'package:appwizard/features/history/di.dart';
import 'package:appwizard/features/main_shell/di.dart';
import 'package:appwizard/features/onboarding/di.dart';
import 'package:appwizard/features/paywall/di.dart';
import 'package:appwizard/features/pro_deal_closer/di.dart';
import 'package:appwizard/features/profile/di.dart';

final sl = GetIt.instance;

/// Initialize dependency injection
Future<void> init() async {
  // Core
  final sharedPreferences = await SharedPreferences.getInstance();
  sl
    ..registerLazySingleton(() => sharedPreferences)
    ..registerLazySingleton<NetworkInfo>(
      () => NetworkInfoImpl(Connectivity()),
    )
    // Register Dio for HTTP requests
    ..registerLazySingleton<Dio>(
      () => Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      ),
    )
    // Register Crashlytics (must be available after Firebase initialization)
    ..registerLazySingleton<FirebaseCrashlytics>(
      () => FirebaseService.crashlytics ?? FirebaseCrashlytics.instance,
    )
    // Register AppLogger with Crashlytics dependency
    ..registerLazySingleton<AppLogger>(
      () => AppLogger(sl<FirebaseCrashlytics>()),
    )
    // Routing
    ..registerLazySingleton<AppRouter>(AppRouter.new)

  // Utils

    ..registerLazySingleton<ColorHelper>(() => ColorHelper(sl<AppLogger>()))
    ..registerLazySingleton<AssetPathHelper>(AssetPathHelper.new)

  // Services

    ..registerLazySingleton<AuthService>(
      () => AuthService(sl<AppLogger>()),
    )
    ..registerLazySingleton<RemoteConfigService>(
      () => RemoteConfigService(sl<AppLogger>()),
    )
    // Typed access to our HTTPS Cloud Functions (base URL from Remote Config). Every call
    // carries the Firebase ID token; AuthService signs in anonymously first when needed.
    ..registerLazySingleton<CloudFunctionsApi>(
      () => CloudFunctionsClient(
        sl<Dio>(),
        sl<RemoteConfigService>(),
        authToken: () => sl<AuthService>().idToken(),
      ),
    )
    ..registerLazySingleton<AnalyticsService>(
      () => AnalyticsService(logger: sl<AppLogger>()),
    )
    ..registerLazySingleton<OnboardingService>(
      () => OnboardingService(
        sl<RemoteConfigService>(),
        sl<AppLogger>(),
      ),
    )
    // Data Sources
    ..registerLazySingleton<OnboardingLocalDataSource>(
      () => OnboardingLocalDataSourceImpl(
        sl<SharedPreferences>(),
        sl<AppLogger>(),
      ),
    )
    // Backend-owned conversations (CONVERSATIONS.md): writes via the `conversations`
    // function, reads via Firestore listeners. MOCK_AI swaps both for an in-memory fake.
    ..registerLazySingleton<FakeConversationsBackend>(FakeConversationsBackend.new)
    ..registerLazySingleton<ConversationsApi>(
      () => AppConfig.useMockAi ? sl<FakeConversationsBackend>() : CloudConversationsApi(sl<CloudFunctionsApi>()),
    )
    ..registerLazySingleton<ConversationsStream>(
      () => AppConfig.useMockAi ? sl<FakeConversationsBackend>() : FirestoreConversationsStream(),
    )
    ..registerLazySingleton<ScreenshotEncoder>(() => const ScreenshotEncoder())
    ..registerLazySingleton<ExpressDealmakerRemoteDataSource>(
      () => CloudExpressDealmakerRemoteDataSource(
        sl<ConversationsApi>(),
        sl<ConversationsStream>(),
        sl<AuthService>(),
        sl<UserProfileService>(),
        sl<ScreenshotEncoder>(),
        sl<AppLogger>(),
      ),
    )
    ..registerLazySingleton<LinesThatLandApiDataSource>(
      () => LinesThatLandApiDataSourceImpl(sl<CloudFunctionsApi>()),
    )
    ..registerLazySingleton<LinesThatLandLocalCache>(
      () => LinesThatLandLocalCacheImpl(sl<SharedPreferences>()),
    )
    ..registerLazySingleton<FeedbackRemoteDataSource>(
      () => FeedbackRemoteDataSourceImpl(
        sl<RemoteConfigService>(),
        sl<Dio>(),
        sl<AppLogger>(),
      ),
    )
    // Mappers (enum mappers registered first, then mappers that depend on them)
    ..registerLazySingleton<OnboardingScreenTypeMapper>(() => OnboardingScreenTypeMapper())
    ..registerLazySingleton<OnboardingDataMapper>(
      () => OnboardingDataMapper(sl<OnboardingScreenTypeMapper>(), sl<AppLogger>()),
    )
    ..registerLazySingleton<UploadScreenshotResultMapper>(() => UploadScreenshotResultMapper())
    ..registerLazySingleton<DealReplyMapper>(() => DealReplyMapper())
    ..registerLazySingleton<LinesThatLandMapper>(() => LinesThatLandMapper())
    ..registerLazySingleton<FeedbackFormMapper>(() => FeedbackFormMapper())
    // Repositories
    ..registerLazySingleton<OnboardingRepository>(
      () => OnboardingRepositoryImpl(
        sl<OnboardingLocalDataSource>(),
        sl<OnboardingDataMapper>(),
        sl<AppLogger>(),
        uploader: (data) => sl<ProfileSyncService>().pushOnboarding(data),
      ),
    )
    ..registerLazySingleton<ConversationRepository>(
      () => ConversationRepositoryImpl(
        api: sl<ConversationsApi>(),
        stream: sl<ConversationsStream>(),
        auth: sl<AuthService>(),
        logger: sl<AppLogger>(),
      ),
    )
    ..registerLazySingleton<ExpressDealmakerRepository>(
      () => ExpressDealmakerRepositoryImpl(
        sl<ExpressDealmakerRemoteDataSource>(),
        sl<UploadScreenshotResultMapper>(),
        sl<DealReplyMapper>(),
        sl<AppLogger>(),
      ),
    )
    ..registerLazySingleton<LinesThatLandRepository>(
      () => LinesThatLandRepositoryImpl(
        api: sl<LinesThatLandApiDataSource>(),
        cache: sl<LinesThatLandLocalCache>(),
        mapper: sl<LinesThatLandMapper>(),
        logger: sl<AppLogger>(),
      ),
    )
    ..registerLazySingleton<FeedbackRepository>(
      () => FeedbackRepositoryImpl(
        sl<FeedbackRemoteDataSource>(),
        sl<FeedbackFormMapper>(),
        sl<AppLogger>(),
      ),
    )
    ..registerLazySingleton<LinesThatLandBloc>(
      () => LinesThatLandBloc(sl<LinesThatLandRepository>()),
    )
    ..registerFactory<FeedbackBloc>(
      () => FeedbackBloc(sl<FeedbackRepository>()),
    );

  // Subscription Services
  // 1. Payment Providers (both, selected via Remote Config)
  sl
    ..registerLazySingleton<IAPPaymentProvider>(
      () => IAPPaymentProvider(sl<AppLogger>()),
    )
    ..registerLazySingleton<StripePaymentProvider>(
      () => StripePaymentProvider(sl<AppLogger>()),
    )
    ..registerLazySingleton<PaymentProvider>(
      () {
        final rc = sl<RemoteConfigService>();
        final type = rc.getPaymentProviderType();
        return type == PaymentProviderType.stripe
            ? sl<StripePaymentProvider>()
            : sl<IAPPaymentProvider>();
      },
    );

  // 2. In-Memory Data Source
  sl.registerLazySingleton<SubscriptionInMemoryDataSource>(
    () => SubscriptionInMemoryDataSourceImpl(sl<AppLogger>()),
  );

  // 3. Subscription Repository (store SDK only; no backend)
  sl.registerLazySingleton<SubscriptionRepository>(
    () => SubscriptionRepositoryImpl(
      sl<PaymentProvider>(),
      sl<SubscriptionInMemoryDataSource>(),
      sl<RemoteConfigService>(),
      sl<SharedPreferences>(),
      sl<AppLogger>(),
    ),
  );

  // 5. Subscription Checker Service
  sl.registerLazySingleton<SubscriptionCheckerService>(
    () => SubscriptionCheckerService(
      sl<SubscriptionRepository>(),
      sl<AppLogger>(),
    ),
  );

  // 6. Subscription BLoC (factory for new instances per widget)
  sl.registerFactory<SubscriptionBloc>(
    () => SubscriptionBloc(
      repository: sl<SubscriptionRepository>(),
      logger: sl<AppLogger>(),
    ),
  );

  // 7. Feature gating (free / basic / premium rules + debug tier override)
  sl.registerLazySingleton<FeatureGateService>(
    () => FeatureGateService(
      sl<SubscriptionCheckerService>(),
      sl<SharedPreferences>(),
      sl<AppLogger>(),
    ),
  );

  // User profile: the onboarding answers as stored, pushed to the `profile` function
  sl.registerLazySingleton<UserProfileService>(
    () => UserProfileService(
      sl<OnboardingRepository>(),
      sl<RemoteConfigService>(),
      sl<AppLogger>(),
      // Resolved lazily: the sync service reads answers back off this one.
      pushToBackend: () => sl<ProfileSyncService>().schedulePush(),
    ),
  );

  // Profile sync: device answers → `profile` Cloud Function → Firestore (PROFILE_SYNC.md)
  sl
    ..registerLazySingleton<ProfileRemoteDataSource>(() => ProfileRemoteDataSourceImpl(sl<CloudFunctionsApi>()))
    ..registerLazySingleton<ProfileSyncService>(
      () => ProfileSyncService(
        profile: sl<UserProfileService>(),
        remote: sl<ProfileRemoteDataSource>(),
        auth: sl<AuthService>(),
        onboarding: sl<OnboardingRepository>(),
        logger: sl<AppLogger>(),
      ),
    );

  // Auth BLoC
  sl.registerFactory<AuthBloc>(
    () => AuthBloc(
      authService: sl<AuthService>(),
      logger: sl<AppLogger>(),
    ),
  );

  // Feature-local registrations (each feature owns its di.dart)
  registerOnboardingDependencies(sl);
  registerExpressDealmakerDependencies(sl);
  registerProDealCloserDependencies(sl);
  registerPaywallDependencies(sl);
  registerProfileDependencies(sl);
  registerHistoryDependencies(sl);
  registerMainShellDependencies(sl);
}

