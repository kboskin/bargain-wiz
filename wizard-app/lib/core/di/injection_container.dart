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
import 'package:appwizard/data/network/network_info_impl.dart';
import 'package:appwizard/data/repositories/onboarding_repository_impl.dart';
import 'package:appwizard/domain/repositories/onboarding_repository.dart';

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

    ..registerLazySingleton<ColorHelper>(ColorHelper.new)
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
    // Repositories
    ..registerLazySingleton<OnboardingRepository>(
      () => OnboardingRepositoryImpl(sl<OnboardingLocalDataSource>()),
    );

  // Subscription Services
  // 1. Payment Provider (based on config)
  if (AppConfig.paymentProviderType == PaymentProviderType.iap) {
    sl.registerLazySingleton<PaymentProvider>(
      () => IAPPaymentProvider(sl<AppLogger>()),
    );
  } else {
    sl.registerLazySingleton<PaymentProvider>(
      () => StripePaymentProvider(sl<AppLogger>()),
    );
  }

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

