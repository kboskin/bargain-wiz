import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:appwizard/core/services/remote_config_service.dart';

/// Error body returned by one of our Cloud Functions: `{"error": {"status": …, "message": …}}`.
class CloudFunctionException implements Exception {
  const CloudFunctionException(this.status, this.message, {this.httpStatus});

  /// e.g. `METHOD_NOT_ALLOWED`, `INVALID_ARGUMENT`, `UNAUTHENTICATED`, `UPSTREAM_ERROR`.
  final String status;
  final String message;
  final int? httpStatus;

  @override
  String toString() => 'CloudFunctionException($status, HTTP $httpStatus): $message';
}

/// Supplies a Firebase ID token for the `Authorization` header, or null when signed out.
typedef AuthTokenProvider = Future<String?> Function();

/// Typed access to the project's HTTPS Cloud Functions (wizard-backend/functions).
///
/// Functions are plain JSON-over-HTTPS endpoints under the remotely configured
/// `api_url`; each feature adds its path and request/response models.
abstract class CloudFunctionsApi {
  /// `GET {api_url}{path}`, decoded with [fromJson].
  ///
  /// Throws [CloudFunctionException] when the function answers with an error body,
  /// [StateError] for anything else unexpected, and [DioException] for transport failures.
  Future<T> get<T>(String path, {required T Function(Map<String, dynamic> json) fromJson});

  /// `POST {api_url}{path}` with a JSON [body], decoded with [fromJson].
  /// Same failure modes as [get].
  Future<T> post<T>(
    String path, {
    required Map<String, dynamic> body,
    required T Function(Map<String, dynamic> json) fromJson,
  });

  /// `PATCH {api_url}{path}` with a JSON [body] (partial update), decoded with
  /// [fromJson]. Same failure modes as [get].
  Future<T> patch<T>(
    String path, {
    required Map<String, dynamic> body,
    required T Function(Map<String, dynamic> json) fromJson,
  });

  /// `DELETE {api_url}{path}`, decoded with [fromJson]. Same failure modes as [get].
  Future<T> delete<T>(String path, {required T Function(Map<String, dynamic> json) fromJson});
}

class CloudFunctionsClient implements CloudFunctionsApi {
  /// [authToken] defaults to the signed-in Firebase user's ID token (none when signed out);
  /// functions accept anonymous calls but use the uid for logging when present.
  /// [postTimeout] overrides Dio's default receive/send timeout for POSTs: the AI functions
  /// may take longer than a plain fetch (their own limit is 60 s).
  CloudFunctionsClient(
    this._dio,
    this._remoteConfig, {
    AuthTokenProvider? authToken,
    Duration postTimeout = const Duration(seconds: 70),
  })  : _authToken = authToken ?? _firebaseIdToken,
        _postTimeout = postTimeout;

  final Dio _dio;
  final RemoteConfigService _remoteConfig;
  final AuthTokenProvider _authToken;
  final Duration _postTimeout;

  static Future<String?> _firebaseIdToken() async {
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken();
    } on Object {
      return null;
    }
  }

  @override
  Future<T> get<T>(String path, {required T Function(Map<String, dynamic> json) fromJson}) =>
      _send(path, method: 'GET', fromJson: fromJson);

  @override
  Future<T> post<T>(
    String path, {
    required Map<String, dynamic> body,
    required T Function(Map<String, dynamic> json) fromJson,
  }) =>
      _send(path, method: 'POST', body: body, fromJson: fromJson);

  @override
  Future<T> patch<T>(
    String path, {
    required Map<String, dynamic> body,
    required T Function(Map<String, dynamic> json) fromJson,
  }) =>
      _send(path, method: 'PATCH', body: body, fromJson: fromJson);

  @override
  Future<T> delete<T>(String path, {required T Function(Map<String, dynamic> json) fromJson}) =>
      _send(path, method: 'DELETE', fromJson: fromJson);

  Future<T> _send<T>(
    String path, {
    required String method,
    required T Function(Map<String, dynamic> json) fromJson,
    Map<String, dynamic>? body,
  }) async {
    final base = _remoteConfig.getApiUrl();
    if (base.isEmpty) throw StateError('Cloud Functions: api_url is not configured');

    final headers = <String, dynamic>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    final token = await _authToken();
    if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

    final response = await _dio.request<dynamic>(
      '$base$path',
      data: body,
      options: Options(
        method: method,
        headers: headers,
        responseType: ResponseType.json,
        receiveTimeout: body != null ? _postTimeout : null,
        sendTimeout: body != null ? _postTimeout : null,
        // Function errors arrive as 4xx/5xx with an error body; read it instead of throwing.
        validateStatus: (_) => true,
      ),
    );

    final data = response.data;
    if (data is Map) {
      final error = data['error'];
      if (error is Map) {
        throw CloudFunctionException(
          error['status']?.toString() ?? 'UNKNOWN',
          error['message']?.toString() ?? '',
          httpStatus: response.statusCode,
        );
      }
      if (response.statusCode == 200) return fromJson(Map<String, dynamic>.from(data));
    }
    throw StateError('Cloud Functions: unexpected response from $path (HTTP ${response.statusCode})');
  }
}
