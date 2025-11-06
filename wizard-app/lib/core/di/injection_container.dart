import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../network/network_info.dart';
import '../../data/network/network_info_impl.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/onboarding_service.dart';
import '../../core/services/remote_config_service.dart';
import '../../core/services/firebase_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/datasources/onboarding_local_datasource.dart';
import '../../data/repositories/onboarding_repository_impl.dart';
import '../../domain/repositories/onboarding_repository.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

final sl = GetIt.instance;

/// Initialize dependency injection
Future<void> init() async {
  // Core
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  
  sl.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(Connectivity()),
  );

  // Register Crashlytics (must be available after Firebase initialization)
  sl.registerLazySingleton<FirebaseCrashlytics>(
    () => FirebaseService.crashlytics ?? FirebaseCrashlytics.instance,
  );

  // Register AppLogger with Crashlytics dependency
  sl.registerLazySingleton<AppLogger>(
    () => AppLogger(sl<FirebaseCrashlytics>()),
  );

  // Services
  sl.registerLazySingleton<AuthService>(
    () => AuthService(sl<AppLogger>()),
  );
  
  sl.registerLazySingleton<RemoteConfigService>(
    () => RemoteConfigService(
      sl<SharedPreferences>(),
      sl<AppLogger>(),
    ),
  );
  
  sl.registerLazySingleton<OnboardingService>(
    () => OnboardingService(
      sl<RemoteConfigService>(),
      sl<AppLogger>(),
    ),
  );

  // Data Sources
  sl.registerLazySingleton<OnboardingLocalDataSource>(
    () => OnboardingLocalDataSourceImpl(
      sl<SharedPreferences>(),
      sl<AppLogger>(),
    ),
  );

  // Repositories
  sl.registerLazySingleton<OnboardingRepository>(
    () => OnboardingRepositoryImpl(
      sl<OnboardingLocalDataSource>(),
    ),
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

