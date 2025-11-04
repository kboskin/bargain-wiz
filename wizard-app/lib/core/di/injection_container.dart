import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/network_info.dart';
import '../../data/network/network_info_impl.dart';
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

