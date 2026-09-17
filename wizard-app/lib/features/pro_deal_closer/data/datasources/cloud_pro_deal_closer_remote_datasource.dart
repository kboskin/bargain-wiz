import 'package:appwizard/core/network/cloud_functions_client.dart';
import 'package:appwizard/core/services/user_profile_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/core/utils/screenshot_encoder.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/pro_deal_closer/data/datasources/pro_deal_closer_remote_datasource.dart';
import 'package:appwizard/features/shared/data/models/ai/ai_api_models.dart';

/// Pro Deal Closer backed by the `pro_deal_closer` Cloud Function (Gemini on Vertex AI).
///
/// The whole chat history is sent each turn (the function trims it); attached screenshots
/// are downscaled once and cached by path for the lifetime of this data source.
class CloudProDealCloserRemoteDataSource implements ProDealCloserRemoteDataSource {
  CloudProDealCloserRemoteDataSource(this._api, this._profile, this._encoder, this._logger);

  static const String path = '/pro_deal_closer';

  /// Newest screenshots win when a chat has more than this many attachments.
  static const int maxImages = 6;

  /// Encoded attachments cached by path across turns; oldest are evicted.
  static const int maxCached = 24;

  final CloudFunctionsApi _api;
  final UserProfileService _profile;
  final ScreenshotEncoder _encoder;
  final AppLogger _logger;

  final Map<String, EncodedImage> _encoded = {};

  @override
  Future<WizardReplyDto> getReply({
    required List<ProDealCloserMessage> history,
    required String vibe,
    required String locale,
    bool regenerate = false,
  }) async {
    final request = await _request(history, vibe: vibe, locale: locale, mode: 'reply', regenerate: regenerate);
    final response = await _api.post(path, body: request.toJson(), fromJson: ProReplyResponse.fromJson);
    if (response.reply.isEmpty) throw StateError('Pro: empty reply');
    return WizardReplyDto(text: response.reply);
  }

  @override
  Future<List<DealOptionDto>> getOptions({
    required List<ProDealCloserMessage> history,
    required String vibe,
    required String locale,
  }) async {
    final request = await _request(history, vibe: vibe, locale: locale, mode: 'options');
    final response = await _api.post(path, body: request.toJson(), fromJson: ProOptionsResponse.fromJson);
    return [
      for (final line in response.lines)
        if (line.text.isNotEmpty) DealOptionDto(text: line.text, intent: line.intent, why: line.why),
    ];
  }

  Future<ProDealCloserRequest> _request(
    List<ProDealCloserMessage> history, {
    required String vibe,
    required String locale,
    required String mode,
    bool regenerate = false,
  }) async {
    var budget = maxImages;
    final messages = <AiChatMessage>[];
    // Walk newest-first so the image budget favours recent screenshots.
    for (final message in history.reversed) {
      List<AiImagePayload>? images;
      if (message.isUser && message.attachmentPaths.isNotEmpty && budget > 0) {
        images = [];
        for (final attachment in message.attachmentPaths.reversed) {
          if (budget == 0) break;
          final encoded = await _encode(attachment);
          if (encoded == null) continue;
          images.insert(0, AiImagePayload(mimeType: encoded.mimeType, data: encoded.base64Data));
          budget--;
        }
        if (images.isEmpty) images = null;
      }
      if (message.text.trim().isEmpty && images == null) continue;
      messages.insert(0, AiChatMessage(role: message.isWizard ? 'wizard' : 'user', text: message.text, images: images));
    }
    return ProDealCloserRequest(
      messages: messages,
      mode: mode,
      regenerate: regenerate,
      locale: locale,
      vibe: vibe,
      push: _profile.pushValue,
      marketplace: _profile.marketplace,
      dealSize: _profile.dealSizeValue,
    );
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
    } on Object catch (e, st) {
      _logger.e('Pro: could not encode attachment $path', e, st);
      return null;
    }
  }
}
