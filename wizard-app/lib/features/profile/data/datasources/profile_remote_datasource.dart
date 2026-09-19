import 'package:appwizard/core/network/cloud_functions_client.dart';
import 'package:appwizard/features/profile/data/models/profile_api_models.dart';

/// The `profile` Cloud Function: partial updates and reads of the user's profile document.
abstract class ProfileRemoteDataSource {
  /// `PATCH /profile`; returns the merged document.
  Future<ProfileDocument> patch(ProfilePatchRequest request);

  /// `GET /profile`; null when no document exists yet. The uid on the ID token selects the
  /// document — the client sends no identity of its own.
  Future<ProfileDocument?> fetch();
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  ProfileRemoteDataSourceImpl(this._api);

  static const String path = '/profile';

  final CloudFunctionsApi _api;

  @override
  Future<ProfileDocument> patch(ProfilePatchRequest request) =>
      _api.patch(path, body: request.toJson(), fromJson: ProfileDocument.fromJson);

  @override
  Future<ProfileDocument?> fetch() async {
    try {
      return await _api.get(path, fromJson: ProfileDocument.fromJson);
    } on CloudFunctionException catch (e) {
      if (e.status == 'NOT_FOUND') return null;
      rethrow;
    }
  }
}
