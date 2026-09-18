import 'package:appwizard/core/network/cloud_functions_client.dart';
import 'package:appwizard/features/profile/data/models/profile_api_models.dart';

/// The `profile` Cloud Function: partial updates and reads of the user's profile document.
abstract class ProfileRemoteDataSource {
  /// `PATCH /profile`; returns the merged document.
  Future<ProfileDocument> patch(ProfilePatchRequest request);

  /// `GET /profile?installation_id=…`; null when no document exists yet.
  Future<ProfileDocument?> fetch({required String installationId});
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  ProfileRemoteDataSourceImpl(this._api);

  static const String path = '/profile';

  final CloudFunctionsApi _api;

  @override
  Future<ProfileDocument> patch(ProfilePatchRequest request) =>
      _api.patch(path, body: request.toJson(), fromJson: ProfileDocument.fromJson);

  @override
  Future<ProfileDocument?> fetch({required String installationId}) async {
    try {
      return await _api.get(
        '$path?installation_id=${Uri.encodeQueryComponent(installationId)}',
        fromJson: ProfileDocument.fromJson,
      );
    } on CloudFunctionException catch (e) {
      if (e.status == 'NOT_FOUND') return null;
      rethrow;
    }
  }
}
