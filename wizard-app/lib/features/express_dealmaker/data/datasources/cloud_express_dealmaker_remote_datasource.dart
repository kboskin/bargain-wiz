import 'package:appwizard/core/services/user_profile_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/core/utils/screenshot_encoder.dart';
import 'package:appwizard/features/conversation/data/datasources/conversations_api.dart';
import 'package:appwizard/features/conversation/data/models/conversation_api_models.dart';
import 'package:appwizard/features/express_dealmaker/data/datasources/express_dealmaker_remote_datasource.dart';
import 'package:appwizard/features/shared/data/models/ai/ai_api_models.dart';

/// Express Dealmaker over the backend-owned `conversations` function (CONVERSATIONS.md).
///
/// "Upload" prepares the screenshot on device (downscaled JPEG kept in memory under an id).
/// The first [getDealReply] creates an `express` conversation with every prepared screenshot
/// and gets the result inline; later calls ("Get More", a tone or keyword change) ask the same
/// conversation to regenerate, so screenshots travel only once.
class CloudExpressDealmakerRemoteDataSource implements ExpressDealmakerRemoteDataSource {
  CloudExpressDealmakerRemoteDataSource(this._api, this._profile, this._encoder, this._logger,
      {String Function()? requestIdGenerator})
      : _requestId = requestIdGenerator ?? _uuid;

  /// Prepared screenshots kept per session (a request uses at most 6); oldest are evicted.
  static const int maxPrepared = 12;

  final ConversationsApi _api;
  final UserProfileService _profile;
  final ScreenshotEncoder _encoder;
  final AppLogger _logger;
  final String Function() _requestId;

  final Map<String, EncodedImage> _prepared = {};
  int _sequence = 0;

  static String _uuid() => DateTime.now().microsecondsSinceEpoch.toRadixString(36).padLeft(12, '0');

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
    final String? conversationId,
  }) async {
    final profile = ConversationProfile(
      vibe: vibe ?? _profile.vibeId,
      push: _profile.pushValue,
      locale: locale,
      marketplace: _profile.marketplace,
      dealSize: _profile.dealSizeValue,
      dealsPerMonth: _profile.dealsPerMonth,
      hurdles: _profile.hurdles.isEmpty ? null : _profile.hurdles,
    );
    final ConversationWriteResponse response;
    if (conversationId != null) {
      response = await _api.redo(
        conversationId,
        ConversationActionRequest(requestId: _requestId(), profile: profile, keyword: keyword),
      );
    } else {
      final images = [
        for (final id in uploadedIds)
          if (_prepared[id] case final image?) AiImagePayload(mimeType: image.mimeType, data: image.base64Data),
      ];
      if (images.isEmpty) throw StateError('Express: no prepared screenshots for $uploadedIds');
      response = await _api.create(CreateConversationRequest(
        type: 'express',
        requestId: _requestId(),
        profile: profile,
        keyword: keyword,
        images: images,
      ));
    }
    final express = response.express;
    if (express == null) throw StateError('Express: the backend returned no result');
    return DealReplyDto(
      conversationId: response.conversationId,
      seeing: express.seeing.isEmpty ? null : express.seeing,
      lines: [
        for (final line in express.lines)
          if (line.text.isNotEmpty) DealLineDto(text: line.text, intent: line.intent, why: line.why),
      ],
    );
  }
}
