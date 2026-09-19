import 'package:appwizard/core/network/cloud_functions_client.dart';
import 'package:appwizard/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:appwizard/features/profile/data/models/profile_api_models.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApi implements CloudFunctionsApi {
  @override
  Future<T> delete<T>(String path, {required T Function(Map<String, dynamic> json) fromJson}) =>
      throw UnimplementedError();

  _FakeApi({this.getResult, this.getError});
  final Map<String, dynamic>? getResult;
  final Object? getError;
  String? lastGetPath;
  String? lastPatchPath;
  Map<String, dynamic>? lastPatchBody;

  @override
  Future<T> get<T>(String path, {required T Function(Map<String, dynamic> json) fromJson}) async {
    lastGetPath = path;
    if (getError != null) throw getError!;
    return fromJson(getResult!);
  }

  @override
  Future<T> post<T>(String path, {required Map<String, dynamic> body, required T Function(Map<String, dynamic> json) fromJson}) =>
      throw UnimplementedError();

  @override
  Future<T> patch<T>(String path, {required Map<String, dynamic> body, required T Function(Map<String, dynamic> json) fromJson}) async {
    lastPatchPath = path;
    lastPatchBody = body;
    return fromJson({'schema_version': 2, ...body});
  }
}

void main() {
  test('patch PATCHes /profile with the partial body and decodes the document', () async {
    final api = _FakeApi();
    final doc = await ProfileRemoteDataSourceImpl(api).patch(
      const ProfilePatchRequest(preferences: {'vibe': 'tactical'}),
    );
    expect(api.lastPatchPath, '/profile');
    expect(api.lastPatchBody, {'preferences': {'vibe': 'tactical'}});
    expect(doc.schemaVersion, 2);
    expect(doc.preferences, {'vibe': 'tactical'});
  });

  test('fetch GETs /profile (the token is the identity) and maps NOT_FOUND to null', () async {
    final api = _FakeApi(getResult: {'identity': {'uid': 'u1'}, 'preferences': {'x': 1},
      'onboarding_status': {'completed_at': '2026-09-17T12:00:00Z'}});
    final doc = await ProfileRemoteDataSourceImpl(api).fetch();
    expect(api.lastGetPath, '/profile');
    expect(doc!.identity!.uid, 'u1');
    expect(doc.preferences, {'x': 1});
    expect(doc.onboardingStatus!.completedAt, '2026-09-17T12:00:00Z');

    final missing = _FakeApi(getError: const CloudFunctionException('NOT_FOUND', 'No profile yet', httpStatus: 404));
    expect(await ProfileRemoteDataSourceImpl(missing).fetch(), isNull);

    final broken = _FakeApi(getError: const CloudFunctionException('INTERNAL', 'boom', httpStatus: 500));
    expect(ProfileRemoteDataSourceImpl(broken).fetch(), throwsA(isA<CloudFunctionException>()));
  });
}
