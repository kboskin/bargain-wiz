import 'dart:convert';
import 'dart:typed_data';

import 'package:appwizard/core/network/cloud_functions_client.dart';
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRemoteConfig implements RemoteConfigService {
  _FakeRemoteConfig(this.baseUrl);

  final String baseUrl;

  @override
  String getApiUrl() => baseUrl;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Answers every request with [handler] and records what Dio sent.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, int status) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );

void main() {
  const base = 'https://us-central1-wizard-app-dev.cloudfunctions.net';

  (CloudFunctionsClient, _FakeAdapter) build(ResponseBody Function(RequestOptions) handler, {String baseUrl = base, String? token}) {
    final adapter = _FakeAdapter(handler);
    final dio = Dio()..httpClientAdapter = adapter;
    return (CloudFunctionsClient(dio, _FakeRemoteConfig(baseUrl), authToken: () async => token), adapter);
  }

  group('CloudFunctionsClient.get', () {
    test('GETs api_url + path with no body and decodes with fromJson', () async {
      final (client, adapter) = build((_) => _json({'answer': 42}, 200));

      final value = await client.get('/echo', fromJson: (json) => json['answer'] as int);

      final req = adapter.requests.single;
      expect(req.method, 'GET');
      expect(req.uri.toString(), '$base/echo');
      expect(req.data, isNull);
      expect(req.headers['Accept'], 'application/json');
      expect(req.headers.containsKey('Authorization'), isFalse); // signed out
      expect(value, 42);
    });

    test('POST sends the JSON body and the Firebase ID token when signed in', () async {
      final (client, adapter) = build((_) => _json({'ok': true}, 200), token: 'id-token');

      final ok = await client.post('/ai', body: {'a': 1}, fromJson: (json) => json['ok'] as bool);

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.uri.toString(), '$base/ai');
      expect(req.data, {'a': 1});
      expect(req.headers['Authorization'], 'Bearer id-token');
      expect(req.headers['Content-Type'], 'application/json');
      expect(req.receiveTimeout, const Duration(seconds: 70)); // AI calls outlive the default
      expect(ok, isTrue);
    });

    test('PATCH sends a JSON body with the same envelope handling', () async {
      final (client, adapter) = build((_) => _json({'merged': true}, 200));

      final merged = await client.patch('/profile', body: {'a': 1}, fromJson: (json) => json['merged'] as bool);

      expect(adapter.requests.single.method, 'PATCH');
      expect(adapter.requests.single.data, {'a': 1});
      expect(merged, isTrue);
    });

    test('surfaces the function error body as CloudFunctionException', () async {
      final (client, _) = build((_) => _json({'error': {'status': 'METHOD_NOT_ALLOWED', 'message': 'Use GET.'}}, 405));

      await expectLater(
        client.get('/echo', fromJson: (json) => json),
        throwsA(isA<CloudFunctionException>()
            .having((e) => e.status, 'status', 'METHOD_NOT_ALLOWED')
            .having((e) => e.message, 'message', 'Use GET.')
            .having((e) => e.httpStatus, 'httpStatus', 405)),
      );
    });

    test('rejects non-object or non-200 responses', () async {
      final (client, _) = build((_) => ResponseBody.fromString('<html>bad gateway</html>', 502));
      await expectLater(client.get('/echo', fromJson: (json) => json), throwsStateError);
    });

    test('fails before any request when api_url is not configured', () async {
      final (client, adapter) = build((_) => _json({}, 200), baseUrl: '');
      await expectLater(client.get('/echo', fromJson: (json) => json), throwsStateError);
      expect(adapter.requests, isEmpty);
    });
  });
}
