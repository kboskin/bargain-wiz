import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:appwizard/core/services/auth_service.dart';
import 'package:appwizard/core/services/firebase_service.dart';
import 'package:appwizard/core/services/onboarding_service.dart';
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/core/utils/asset_path_helper.dart';
import 'package:appwizard/core/utils/color_helper.dart';
import 'package:appwizard/core/utils/multilocale_text_helper.dart';
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
    // Register Crashlytics (must be available after Firebase initialization)
    ..registerLazySingleton<FirebaseCrashlytics>(
      () => FirebaseService.crashlytics ?? FirebaseCrashlytics.instance,
    )
    // Register AppLogger with Crashlytics dependency
    ..registerLazySingleton<AppLogger>(
      () => AppLogger(sl<FirebaseCrashlytics>()),
    )

  // Utils

    ..registerLazySingleton<ColorHelper>(ColorHelper.new)
    ..registerLazySingleton<AssetPathHelper>(AssetPathHelper.new)
    ..registerLazySingleton<MultilocaleTextHelper>(
      () => const MultilocaleTextHelper(),
    )

  // Services

    ..registerLazySingleton<AuthService>(
      () => AuthService(sl<AppLogger>()),
    )
    ..registerLazySingleton<RemoteConfigService>(
      () => RemoteConfigService(sl<AppLogger>()),
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

  // Add your repositories, datasources, and use cases here
  // Example:
  // sl.registerLazySingleton<Repository>(
  //   () => RepositoryImpl(
  //     remoteDataSource: sl(),
  //     localDataSource: sl(),
  //     networkInfo: sl(),
  //   ),
  // );
}

