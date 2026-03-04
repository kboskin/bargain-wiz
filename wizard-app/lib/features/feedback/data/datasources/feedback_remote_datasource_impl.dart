import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/feedback/data/datasources/feedback_remote_datasource.dart';
import 'package:appwizard/features/feedback/data/models/feedback_form_config_model.dart';

class FeedbackRemoteDataSourceImpl implements FeedbackRemoteDataSource {
  FeedbackRemoteDataSourceImpl(
    this._remoteConfig,
    this._dio,
    this._logger,
  );

  final RemoteConfigService _remoteConfig;
  final Dio _dio;
  final AppLogger _logger;

  static const String _configKey = 'feedback_form_config';

  @override
  Future<FeedbackFormConfigModel?> getFeedbackFormConfig() async {
    try {
      final jsonString = _remoteConfig.getString(_configKey);
      if (jsonString.isEmpty) return null;
      final json = jsonDecode(jsonString) as Map<String, dynamic>?;
      if (json == null) return null;
      return FeedbackFormConfigModel.fromJson(json);
    } catch (e, st) {
      _logger.e('getFeedbackFormConfig failed', e, st);
      return null;
    }
  }

  @override
  Future<void> submitFeedback(
    Map<String, String> values,
    String submitUrl,
  ) async {
    if (values.isEmpty || submitUrl.isEmpty) return;
    try {
      await _dio.post<void>(
        submitUrl,
        data: values,
        options: Options(
          contentType: Headers.jsonContentType,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
    } catch (e, st) {
      _logger.e('submitFeedback failed', e, st);
      rethrow;
    }
  }
}
