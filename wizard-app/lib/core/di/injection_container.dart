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
import 'package:appwizard/presentation/bloc/auth/auth_bloc.dart';
import 'package:appwizard/core/services/subscription/payment_provider.dart';
import 'package:appwizard/core/services/subscription/iap_payment_provider.dart';
import 'package:appwizard/core/services/subscription/stripe_payment_provider.dart';
import 'package:appwizard/core/services/subscription/subscription_sync_service.dart';
import 'package:appwizard/core/services/subscription/subscription_checker_service.dart';
import 'package:appwizard/core/config/app_config.dart';
import 'package:appwizard/data/datasources/subscription_in_memory_datasource.dart';
import 'package:appwizard/domain/repositories/subscription_repository.dart';
import 'package:appwizard/data/repositories/subscription_repository_impl.dart';
import 'package:appwizard/presentation/bloc/subscription/subscription_bloc.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/core/utils/asset_path_helper.dart';
import 'package:appwizard/core/utils/color_helper.dart';
import 'package:appwizard/data/datasources/onboarding_local_datasource.dart';
import 'package:appwizard/data/datasources/express_dealmaker_remote_datasource.dart';
import 'package:appwizard/data/datasources/conversation_local_datasource.dart';
import 'package:appwizard/data/mappers/conversation_mapper.dart';
import 'package:appwizard/data/mappers/conversation_type_mapper.dart';
import 'package:appwizard/data/mappers/onboarding_data_mapper.dart';
import 'package:appwizard/data/mappers/onboarding_screen_type_mapper.dart';
import 'package:appwizard/data/mappers/express_dealmaker_mapper.dart';
import 'package:appwizard/data/network/network_info_impl.dart';
import 'package:appwizard/data/repositories/onboarding_repository_impl.dart';
import 'package:appwizard/data/repositories/express_dealmaker_repository_impl.dart';
import 'package:appwizard/data/repositories/conversation_repository_impl.dart';
import 'package:appwizard/data/repositories/feedback_repository_impl.dart';
import 'package:appwizard/data/repositories/lines_that_land_repository_impl.dart';
import 'package:appwizard/data/datasources/feedback_remote_datasource.dart';
import 'package:appwizard/data/datasources/feedback_remote_datasource_impl.dart';
import 'package:appwizard/data/datasources/lines_that_land_remote_datasource.dart';
import 'package:appwizard/data/mappers/feedback_form_mapper.dart';
import 'package:appwizard/data/mappers/lines_that_land_mapper.dart';
import 'package:appwizard/domain/repositories/onboarding_repository.dart';
import 'package:appwizard/domain/repositories/express_dealmaker_repository.dart';
import 'package:appwizard/domain/repositories/conversation_repository.dart';
import 'package:appwizard/domain/repositories/feedback_repository.dart';
import 'package:appwizard/domain/repositories/lines_that_land_repository.dart';
import 'package:appwizard/presentation/bloc/feedback/feedback_bloc.dart';
import 'package:appwizard/presentation/bloc/lines_that_land/lines_that_land_bloc.dart';

import 'package:appwizard/core/network/network_info.dart';

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
    ..registerLazySingleton<ConversationLocalDataSource>(
      () => ConversationLocalDataSourceImpl(
        sl<SharedPreferences>(),
        sl<AppLogger>(),
      ),
    )
    ..registerLazySingleton<ExpressDealmakerRemoteDataSource>(
      () => MockExpressDealmakerRemoteDataSource(sl<AppLogger>()),
    )
    ..registerLazySingleton<LinesThatLandRemoteDataSource>(
      () => LinesThatLandRemoteDataSourceImpl(sl<RemoteConfigService>()),
    )
    ..registerLazySingleton<FeedbackRemoteDataSource>(
      () => FeedbackRemoteDataSourceImpl(
        sl<RemoteConfigService>(),
        sl<Dio>(),
        sl<AppLogger>(),
      ),
    )
    // Mappers (enum mappers registered first, then mappers that depend on them)
    ..registerLazySingleton<ConversationTypeMapper>(() => ConversationTypeMapper())
    ..registerLazySingleton<ConversationMapper>(
      () => ConversationMapper(sl<ConversationTypeMapper>(), sl<AppLogger>()),
    )
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
      ),
    )
    ..registerLazySingleton<ConversationRepository>(
      () => ConversationRepositoryImpl(
        sl<ConversationLocalDataSource>(),
        sl<ConversationMapper>(),
        sl<AppLogger>(),
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
        sl<LinesThatLandRemoteDataSource>(),
        sl<LinesThatLandMapper>(),
        sl<AppLogger>(),
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

  // 3. Subscription Sync Service
  sl.registerLazySingleton<SubscriptionSyncService>(
    () => SubscriptionSyncService(
      sl<AuthService>(),
      sl<Dio>(),
      sl<AppLogger>(),
    ),
  );

  // 4. Subscription Repository
  sl.registerLazySingleton<SubscriptionRepository>(
    () => SubscriptionRepositoryImpl(
      sl<PaymentProvider>(),
      sl<SubscriptionSyncService>(),
      sl<SubscriptionInMemoryDataSource>(),
      sl<RemoteConfigService>(),
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

  // Auth BLoC
  sl.registerFactory<AuthBloc>(
    () => AuthBloc(
      authService: sl<AuthService>(),
      logger: sl<AppLogger>(),
    ),
  );
}

