import 'package:appwizard/core/network/cloud_functions_client.dart';
import 'package:appwizard/features/lines_that_land/data/models/lines_that_land_response.dart';

/// The `lines_that_land` HTTPS Cloud Function (wizard-backend/functions), fetched through
/// [CloudFunctionsApi]. The function owns the content (reads Remote Config server-side)
/// and declares how often it changes via `refresh_interval_hours`. See LINES_THAT_LAND.md.
abstract class LinesThatLandApiDataSource {
  /// Fetches the current feed; throws on network, function or parsing failure.
  Future<LinesThatLandResponse> fetchFeed();
}

class LinesThatLandApiDataSourceImpl implements LinesThatLandApiDataSource {
  LinesThatLandApiDataSourceImpl(this._api);

  static const String path = '/lines_that_land';

  final CloudFunctionsApi _api;

  @override
  Future<LinesThatLandResponse> fetchFeed() => _api.get(path, fromJson: LinesThatLandResponse.fromJson);
}
