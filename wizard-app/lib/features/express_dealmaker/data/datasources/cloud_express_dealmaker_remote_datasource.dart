import 'dart:async';

import 'package:appwizard/core/config/attachment_limits.dart';
import 'package:appwizard/core/network/cloud_functions_client.dart';
import 'package:appwizard/core/services/auth_service.dart';
import 'package:appwizard/core/services/user_profile_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/core/utils/screenshot_encoder.dart';
import 'package:appwizard/features/conversation/data/datasources/conversations_api.dart';
import 'package:appwizard/features/conversation/data/datasources/conversations_stream.dart';
import 'package:appwizard/features/conversation/data/models/conversation_api_models.dart';
import 'package:appwizard/features/express_dealmaker/data/datasources/express_dealmaker_remote_datasource.dart';
import 'package:appwizard/features/profile/domain/profile_fields.dart';
import 'package:appwizard/features/shared/data/models/ai/ai_api_models.dart';

/// Express Dealmaker over the backend-owned `conversations` function (CONVERSATIONS.md).
///
/// "Upload" prepares the screenshot on device (downscaled JPEG kept in memory under an id).
/// The first [getDealReply] creates an `express` conversation with every prepared screenshot;
/// later calls ("Get More", a tone or keyword change) ask the same conversation to regenerate,
/// so screenshots travel only once. The backend queues the model call, so both cases wait for
/// the result on the conversation document rather than in the HTTP response.
class CloudExpressDealmakerRemoteDataSource implements ExpressDealmakerRemoteDataSource {
  CloudExpressDealmakerRemoteDataSource(
    this._api,
    this._stream,
    this._auth,
    this._profile,
    this._encoder,
    this._logger, {
    this.resultTimeout = const Duration(seconds: 90),
  });

  /// Prepared screenshots kept per session; oldest are evicted, so the cache never
  /// holds more than one request may carry.
  static const int maxPrepared = AttachmentLimits.maxImages;

  /// What the backend answers a `redo` with while the previous turn is still generating.
  static const String turnInProgress = 'TURN_IN_PROGRESS';

  final ConversationsApi _api;
  final ConversationsStream _stream;
  final AuthService _auth;
  final UserProfileService _profile;
  final ScreenshotEncoder _encoder;
  final AppLogger _logger;

  /// How long to wait for the queued result before giving up.
  final Duration resultTimeout;

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
    _logger.i('Express: prepared $filePath → ${encoded.bytes.length} B');
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
    final profile = ConversationProfile.of(
      _profile.snapshot(
        overrides: vibe == null ? const {} : {ProfileFields.vibeKey: vibe},
        except: const {ProfileFields.referralKey},
      ),
      locale: locale,
    );
    if (conversationId != null) {
      try {
        await _api.redo(conversationId, ConversationActionRequest(profile: profile, keyword: keyword));
      } on CloudFunctionException catch (e) {
        // A retry after the wait ran out: the turn we gave up on is still generating, so wait
        // for that one instead of queueing a second.
        if (e.status != turnInProgress) rethrow;
        _logger.i('Express: $conversationId is already generating — waiting for that turn');
      }
      return _awaitResult(conversationId);
    }
    final images = [
      for (final id in uploadedIds)
        if (_prepared[id] case final image?) AiImagePayload(mimeType: image.mimeType, data: image.base64Data),
    ];
    if (images.isEmpty) throw StateError('Express: no prepared screenshots for $uploadedIds');
    final response = await _api.create(CreateConversationRequest(
      type: 'express',
      profile: profile,
      keyword: keyword,
      images: images,
    ));
    return _awaitResult(response.conversationId);
  }

  /// The wizard is "typing" until the queued generation finishes; the answer is then on the
  /// conversation document. No lines by then means the turn failed.
  ///
  /// Every outcome from here on names the conversation, because the backend created it before
  /// it started generating: a retry has to regenerate that deal, not start another.
  Future<DealReplyDto> _awaitResult(String conversationId) async {
    final uid = await _auth.ensureUid();
    if (uid == null) throw StateError('Express: no Firebase user yet (offline?)');
    final done = await _stream
        .watchConversation(uid, conversationId)
        .firstWhere((conversation) => conversation == null || !conversation.isTyping)
        .timeout(
          resultTimeout,
          onTimeout: () => throw ExpressGenerationException(
            conversationId,
            'The wizard is taking longer than usual. Try again.',
          ),
        );
    if (done == null) throw StateError('Express: the deal was removed while the wizard worked on it');
    final lines = done.effectiveLines;
    // The backend records why it failed on the conversation (`last_error`); prefer that over a
    // blanket message, so an unavailable model reads differently from an empty answer.
    if (lines.isEmpty) {
      throw ExpressGenerationException(conversationId, done.errorMessage ?? 'The wizard could not answer. Try again.');
    }
    return DealReplyDto(
      conversationId: conversationId,
      seeing: done.seeing,
      lines: [for (final line in lines) DealLineDto(text: line.text, intent: line.intent.name, why: line.why)],
    );
  }
}
