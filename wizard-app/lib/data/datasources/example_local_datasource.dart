import '../models/example_model.dart';
import 'datasource.dart';
import '../../core/error/exceptions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Example local data source implementation
class ExampleLocalDataSource implements LocalDataSource, DataSource<ExampleModel> {
  final SharedPreferences sharedPreferences;
  static const String _cacheKey = 'CACHED_EXAMPLE';

  ExampleLocalDataSource(this.sharedPreferences);

  @override
  Future<ExampleModel> getData() async {
    try {
      final jsonString = sharedPreferences.getString(_cacheKey);
      if (jsonString != null) {
        return ExampleModel.fromJson(json.decode(jsonString) as Map<String, dynamic>);
      }
      throw CacheException('No cached data found');
    } catch (e) {
      if (e is CacheException) {
        rethrow;
      }
      throw CacheException('Failed to get cached data: $e');
    }
  }

  Future<void> cacheData(ExampleModel model) async {
    try {
      final jsonString = json.encode(model.toJson());
      await sharedPreferences.setString(_cacheKey, jsonString);
    } catch (e) {
      throw CacheException('Failed to cache data: $e');
    }
  }
}

