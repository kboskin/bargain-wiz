import 'package:dio/dio.dart';

import 'package:appwizard/core/services/remote_config_service.dart';

/// Error body returned by one of our Cloud Functions: `{"error": {"status": …, "message": …}}`.
class CloudFunctionException implements Exception {
  const CloudFunctionException(this.status, this.message, {this.httpStatus});

  /// e.g. `METHOD_NOT_ALLOWED`, `INVALID_ARGUMENT`, `INTERNAL`.
  final String status;
  final String message;
  final int? httpStatus;

  @override
  String toString() => 'CloudFunctionException($status, HTTP $httpStatus): $message';
}

/// Typed access to the project's HTTPS Cloud Functions (wizard-backend/functions).
///
/// Functions are plain JSON-over-HTTPS endpoints under the remotely configured
/// `functions_base_url`; each feature adds its path and response model.
abstract class CloudFunctionsApi {
  /// `GET {functions_base_url}{path}`, decoded with [fromJson].
  ///
  /// Throws [CloudFunctionException] when the function answers with an error body,
  /// [StateError] for anything else unexpected, and [DioException] for transport failures.
  Future<T> get<T>(String path, {required T Function(Map<String, dynamic> json) fromJson});
}

class CloudFunctionsClient implements CloudFunctionsApi {
  CloudFunctionsClient(this._dio, this._remoteConfig);

  final Dio _dio;
  final RemoteConfigService _remoteConfig;

  @override
  Future<T> get<T>(String path, {required T Function(Map<String, dynamic> json) fromJson}) async {
    final base = _remoteConfig.getFunctionsBaseUrl();
    if (base.isEmpty) throw StateError('Cloud Functions: functions_base_url is not configured');

    final response = await _dio.get<dynamic>(
      '$base$path',
      options: Options(
        headers: const {'Accept': 'application/json'},
        responseType: ResponseType.json,
        // Function errors arrive as 4xx/5xx with an error body; read it instead of throwing.
        validateStatus: (_) => true,
      ),
    );

    final body = response.data;
    if (body is Map) {
      final error = body['error'];
      if (error is Map) {
        throw CloudFunctionException(
          error['status']?.toString() ?? 'UNKNOWN',
          error['message']?.toString() ?? '',
          httpStatus: response.statusCode,
        );
      }
      if (response.statusCode == 200) return fromJson(Map<String, dynamic>.from(body));
    }
    throw StateError('Cloud Functions: unexpected response from $path (HTTP ${response.statusCode})');
  }
}
