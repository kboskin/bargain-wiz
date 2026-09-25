/// Result of a single screenshot upload.
class UploadScreenshotResultDto {
  const UploadScreenshotResultDto({this.id});
  final String? id;
}

/// One line in a deal reply DTO.
class DealLineDto {
  const DealLineDto({required this.text, this.intent, this.why});
  final String text;
  /// "opener" | "counter" | "close"
  final String? intent;
  final String? why;
}

/// Deal reply DTO from backend (what was seen + multiple lines).
class DealReplyDto {
  const DealReplyDto({required this.lines, this.seeing, this.conversationId});
  final List<DealLineDto> lines;
  final String? seeing;
  /// Backend conversation holding this deal.
  final String? conversationId;
}

/// A turn the backend accepted and then could not finish (the model failed, or the wait for
/// the queued result ran out).
///
/// The conversation exists on the server from the moment the turn is accepted, so carrying its
/// id out of the failure is what lets a retry regenerate that deal instead of creating a
/// second one.
class ExpressGenerationException implements Exception {
  const ExpressGenerationException(this.conversationId, this.message);

  final String conversationId;

  /// User-safe: the backend's `last_error` when it recorded one.
  final String message;

  @override
  String toString() => 'ExpressGenerationException($conversationId): $message';
}

/// Remote data source for Express Dealmaker (upload screenshots, get reply).
abstract class ExpressDealmakerRemoteDataSource {
  Future<UploadScreenshotResultDto> uploadScreenshot(final String filePath);
  /// "Lines that land" API: returns deal reply options in the requested [locale].
  Future<DealReplyDto> getDealReply({
    required final List<String> uploadedIds,
    required final String locale,
    final String? keyword,
    /// Conversation-scoped answers this deal overrides, `{answer key: value}` — the ones
    /// the template marks `scope: "conversation"`. Empty means "use the stored profile".
    final Map<String, dynamic> overrides,
    /// Existing backend conversation to regenerate ("Get More", an override change); null
    /// creates one.
    final String? conversationId,
  });
}
