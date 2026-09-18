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
    return fromJson({'schema_version': 1, ...body});
  }
}

void main() {
  test('patch PATCHes /profile with the partial body and decodes the document', () async {
    final api = _FakeApi();
    final doc = await ProfileRemoteDataSourceImpl(api).patch(
      const ProfilePatchRequest(installationId: 'abc', preferences: ProfilePreferences(vibe: 'tactical')),
    );
    expect(api.lastPatchPath, '/profile');
    expect(api.lastPatchBody, {'installation_id': 'abc', 'preferences': {'vibe': 'tactical'}});
    expect(doc.schemaVersion, 1);
    expect(doc.preferences!.vibe, 'tactical');
  });

  test('fetch GETs /profile with the installation id and maps NOT_FOUND to null', () async {
    final api = _FakeApi(getResult: {'identity': {'uid': 'u1'}, 'onboarding': {'answers': {'x': 1}}});
    final doc = await ProfileRemoteDataSourceImpl(api).fetch(installationId: 'ab cd');
    expect(api.lastGetPath, '/profile?installation_id=ab+cd');
    expect(doc!.identity!.uid, 'u1');
    expect(doc.onboarding!.answers, {'x': 1});

    final missing = _FakeApi(getError: const CloudFunctionException('NOT_FOUND', 'No profile yet', httpStatus: 404));
    expect(await ProfileRemoteDataSourceImpl(missing).fetch(installationId: 'x'), isNull);

    final broken = _FakeApi(getError: const CloudFunctionException('INTERNAL', 'boom', httpStatus: 500));
    expect(ProfileRemoteDataSourceImpl(broken).fetch(installationId: 'x'), throwsA(isA<CloudFunctionException>()));
  });
}
