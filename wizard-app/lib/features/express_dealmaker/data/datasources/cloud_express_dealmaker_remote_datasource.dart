import 'package:appwizard/core/network/cloud_functions_client.dart';
import 'package:appwizard/core/services/user_profile_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/core/utils/screenshot_encoder.dart';
import 'package:appwizard/features/express_dealmaker/data/datasources/express_dealmaker_remote_datasource.dart';
import 'package:appwizard/features/shared/data/models/ai/ai_api_models.dart';

/// Express Dealmaker backed by the `express_dealmaker` Cloud Function (Gemini on Vertex AI).
///
/// "Upload" prepares the screenshot on device (downscaled JPEG kept in memory under an id);
/// the network call happens once in [getDealReply], which sends every prepared screenshot
/// plus the buyer's profile (vibe, push, marketplace, deal size) and keyword.
class CloudExpressDealmakerRemoteDataSource implements ExpressDealmakerRemoteDataSource {
  CloudExpressDealmakerRemoteDataSource(this._api, this._profile, this._encoder, this._logger);

  static const String path = '/express_dealmaker';

  /// Prepared screenshots kept per session (a request uses at most 6); oldest are evicted.
  static const int maxPrepared = 12;

  final CloudFunctionsApi _api;
  final UserProfileService _profile;
  final ScreenshotEncoder _encoder;
  final AppLogger _logger;

  final Map<String, EncodedImage> _prepared = {};
  int _sequence = 0;

  @override
  Future<UploadScreenshotResultDto> uploadScreenshot(final String filePath) async {
    final encoded = await _encoder.encode(filePath);
    final id = 'shot_${++_sequence}';
    _prepared[id] = encoded;
    while (_prepared.length > maxPrepared) {
      _prepared.remove(_prepared.keys.first);
    }
    _logger.i('Express: prepared $filePath → ${encoded.width}×${encoded.height}, ${encoded.bytes.length} B');
    return UploadScreenshotResultDto(id: id);
  }

  @override
  Future<DealReplyDto> getDealReply({
    required final List<String> uploadedIds,
    required final String locale,
    final String? keyword,
    final String? vibe,
  }) async {
    final images = [
      for (final id in uploadedIds)
        if (_prepared[id] case final image?) AiImagePayload(mimeType: image.mimeType, data: image.base64Data),
    ];
    if (images.isEmpty) throw StateError('Express: no prepared screenshots for $uploadedIds');

    final request = ExpressDealmakerRequest(
      images: images,
      keyword: keyword,
      locale: locale,
      vibe: vibe ?? _profile.vibeId,
      push: _profile.pushValue,
      marketplace: _profile.marketplace,
      dealSize: _profile.dealSizeValue,
    );
    final response = await _api.post(path, body: request.toJson(), fromJson: ExpressDealmakerResponse.fromJson);
    return DealReplyDto(
      seeing: response.seeing.isEmpty ? null : response.seeing,
      lines: [
        for (final line in response.lines)
          if (line.text.isNotEmpty) DealLineDto(text: line.text, intent: line.intent, why: line.why),
      ],
    );
  }
}
