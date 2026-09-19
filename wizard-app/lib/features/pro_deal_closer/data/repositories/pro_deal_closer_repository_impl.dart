import 'package:appwizard/core/config/attachment_limits.dart';
import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/core/network/cloud_functions_client.dart';
import 'package:appwizard/core/services/auth_service.dart';
import 'package:appwizard/core/services/user_profile_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/core/utils/screenshot_encoder.dart';
import 'package:appwizard/features/conversation/data/datasources/conversations_api.dart';
import 'package:appwizard/features/conversation/data/datasources/conversations_stream.dart';
import 'package:appwizard/features/conversation/data/models/conversation_api_models.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/profile/domain/profile_fields.dart';
import 'package:appwizard/features/pro_deal_closer/domain/entities/chat_send_result.dart';
import 'package:appwizard/features/pro_deal_closer/domain/repositories/pro_deal_closer_repository.dart';
import 'package:appwizard/features/shared/data/models/ai/ai_api_models.dart';
import 'package:dartz/dartz.dart';

/// Talks to the `conversations` function and its Firestore listener. Screenshots are
/// downscaled once per path (cached for this session) and sent only with the turn that
/// attaches them; the server keeps them for later turns.
class ProDealCloserRepositoryImpl implements ProDealCloserRepository {
  ProDealCloserRepositoryImpl({
    required ConversationsApi api,
    required ConversationsStream stream,
    required AuthService auth,
    required UserProfileService profile,
    required ScreenshotEncoder encoder,
    required AppLogger logger,
  })  : _api = api,
        _stream = stream,
        _auth = auth,
        _profile = profile,
        _encoder = encoder,
        _logger = logger;

  static const int maxCached = 24;

  final ConversationsApi _api;
  final ConversationsStream _stream;
  final AuthService _auth;
  final UserProfileService _profile;
  final ScreenshotEncoder _encoder;
  final AppLogger _logger;

  final Map<String, EncodedImage> _encoded = {};

  @override
  Stream<List<ProDealCloserMessage>> watchMessages(String conversationId) async* {
    final uid = await _auth.ensureUid();
    if (uid == null) throw StateError('Pro: no Firebase user yet (offline?)');
    yield* _stream.watchMessages(uid, conversationId);
  }

  @override
  Future<Either<Failure, ChatSendResult>> send({
    String? conversationId,
    String? text,
    List<String> attachmentPaths = const [],
    required String vibe,
    required String locale,
  }) async {
    try {
      final images = await _encodeAll(attachmentPaths);
      final profile = _profileFields(vibe, locale);
      final payloadText = (text ?? '').trim().isEmpty ? null : text!.trim();
      final response = conversationId == null
          ? await _api.create(CreateConversationRequest(
              type: 'pro',
              profile: profile,
              text: payloadText,
              images: images.isEmpty ? null : images,
            ))
          : await _api.send(
              conversationId,
              SendMessageRequest(
                profile: profile,
                text: payloadText,
                images: images.isEmpty ? null : images,
              ),
            );
      return Right(ChatSendResult(
        conversationId: response.conversationId,
        messageId: response.messageId,
        replyId: response.replyId,
      ));
    } on Object catch (e, stackTrace) {
      _logger.e('Pro Deal Closer send failed', e, stackTrace);
      return Left(_failure(e));
    }
  }

  @override
  Future<Either<Failure, void>> requestOptions({
    required String conversationId,
    required String messageId,
    required String vibe,
    required String locale,
  }) async {
    try {
      await _api.requestOptions(
        conversationId,
        ConversationActionRequest(messageId: messageId, profile: _profileFields(vibe, locale)),
      );
      return const Right(null);
    } on Object catch (e, stackTrace) {
      _logger.e('Pro Deal Closer options failed', e, stackTrace);
      return Left(_failure(e));
    }
  }

  @override
  Future<Either<Failure, void>> redo({
    required String conversationId,
    required String messageId,
    required String vibe,
    required String locale,
  }) async {
    try {
      await _api.redo(
        conversationId,
        ConversationActionRequest(messageId: messageId, profile: _profileFields(vibe, locale)),
      );
      return const Right(null);
    } on Object catch (e, stackTrace) {
      _logger.e('Pro Deal Closer redo failed', e, stackTrace);
      return Left(_failure(e));
    }
  }

  ConversationProfile _profileFields(String vibe, String locale) => ConversationProfile(
        _profile.payload(
          overrides: {ProfileFields.vibeKey: vibe},
          except: const {ProfileFields.referralKey},
        ),
        locale: locale,
      );

  /// Newest [AttachmentLimits.maxImages] attachments, downscaled; unreadable files are skipped.
  Future<List<AiImagePayload>> _encodeAll(List<String> paths) async {
    const limit = AttachmentLimits.maxImages;
    final kept = paths.length > limit ? paths.sublist(paths.length - limit) : paths;
    final images = <AiImagePayload>[];
    for (final path in kept) {
      final encoded = await _encode(path);
      if (encoded != null) images.add(AiImagePayload(mimeType: encoded.mimeType, data: encoded.base64Data));
    }
    return images;
  }

  Future<EncodedImage?> _encode(String path) async {
    final cached = _encoded[path];
    if (cached != null) return cached;
    try {
      final encoded = await _encoder.encode(path);
      _encoded[path] = encoded;
      while (_encoded.length > maxCached) {
        _encoded.remove(_encoded.keys.first);
      }
      return encoded;
    } on Object catch (e, stackTrace) {
      _logger.e('Pro: could not encode attachment $path', e, stackTrace);
      return null;
    }
  }

  static Failure _failure(Object e) => e is CloudFunctionException ? ServerFailure(e.message) : ServerFailure(e.toString());
}
