import 'package:appwizard/core/services/remote_config_service.dart';

/// Remote data source for "Lines that land" (tips and categories).
abstract class LinesThatLandRemoteDataSource {
  /// Legacy: flat list of tip strings (key: lines_that_land_tips).
  Future<List<String>> getTips();

  /// Categories with id, name, tips (key: lines_that_land_categories).
  Future<List<Map<String, dynamic>>> getCategories();
}

class LinesThatLandRemoteDataSourceImpl implements LinesThatLandRemoteDataSource {
  LinesThatLandRemoteDataSourceImpl(this._remoteConfig);

  final RemoteConfigService _remoteConfig;

  @override
  Future<List<String>> getTips() async {
    return _remoteConfig.getLinesThatLandTips();
  }

  @override
  Future<List<Map<String, dynamic>>> getCategories() async {
    return _remoteConfig.getLinesThatLandCategories();
  }
}
