import 'package:appwizard/core/utils/app_logger.dart';

/// Result of a single screenshot upload (mock/API).
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
  /// Backend conversation holding this deal (null for mocks).
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
/// Implement with mock or real HTTP client.
abstract class ExpressDealmakerRemoteDataSource {
  Future<UploadScreenshotResultDto> uploadScreenshot(final String filePath);
  /// "Lines that land" API: returns deal reply options in the requested [locale].
  Future<DealReplyDto> getDealReply({
    required final List<String> uploadedIds,
    required final String locale,
    final String? keyword,
    /// Negotiation vibe id ("friendly" | "no_nonsense" | "tactical" | "quiet_closer").
    final String? vibe,
    /// Existing backend conversation to regenerate ("Get More", tone change); null creates one.
    final String? conversationId,
  });
}

/// Mock implementation: simulates delay for uploads and returns the
/// vibe-specific reply set from the design prototype.
///
/// QA hooks: a keyword equal to [failKeyword] makes [getDealReply] throw so the
/// error state can be exercised.
class MockExpressDealmakerRemoteDataSource implements ExpressDealmakerRemoteDataSource {
  MockExpressDealmakerRemoteDataSource(this._logger);

  final AppLogger _logger;
  static const Duration _uploadDelay = Duration(milliseconds: 2200);
  static const Duration _getReplyDelay = Duration(milliseconds: 1200);

  static const String failKeyword = 'fail';
  static const String defaultVibe = 'friendly';

  /// What the wizard "sees" in the mock screenshots.
  static const String seeing = r'IKEA Kallax shelf · $180 · listed 9 days · "slight scuff"';

  /// Reply sets per vibe (verbatim from the prototype `REPLY_SETS`).
  static const Map<String, List<DealLineDto>> replySets = {
    'friendly': [
      DealLineDto(
        intent: 'opener',
        text: r'Hi! Is the Kallax still available? I could pick it up today if $140 works for you.',
        why: 'Warm open, signals a fast easy sale, anchors 22% under ask.',
      ),
      DealLineDto(
        intent: 'counter',
        text: r'Totally understand. Could you do $160 if I bring cash tonight and handle the loading?',
        why: 'Concedes a little while adding certainty and effort on your side.',
      ),
      DealLineDto(
        intent: 'close',
        text: r'$160 sounds good — what time works for pickup today?',
        why: 'Assumes the yes and moves straight to logistics.',
      ),
    ],
    'no_nonsense': [
      DealLineDto(
        intent: 'opener',
        text: r'Still available? $140 cash, pickup today.',
        why: 'Short and decisive. Sellers on Marketplace respond to speed.',
      ),
      DealLineDto(
        intent: 'counter',
        text: r'$160 is my max. I can be there in an hour.',
        why: "A firm ceiling plus immediacy removes the seller's reason to wait.",
      ),
      DealLineDto(
        intent: 'close',
        text: r'Deal at $160. Send the address.',
        why: 'Closes without reopening price.',
      ),
    ],
    'tactical': [
      DealLineDto(
        intent: 'opener',
        text: r'Two identical Kallax units sold this week for $130–150 in this area. Would you take $140?',
        why: 'Anchors with comparable data rather than opinion.',
      ),
      DealLineDto(
        intent: 'counter',
        text: r'Given the scuff on the corner and the retail price is $179 new, $160 is fair for both of us.',
        why: 'Names a flaw and the new price to frame the counter as reasonable.',
      ),
      DealLineDto(
        intent: 'close',
        text: r"Let's lock in $160. I'll bring exact cash and pick up at your convenience.",
        why: 'Removes friction and rewards the agreement.',
      ),
    ],
    'quiet_closer': [
      DealLineDto(
        intent: 'opener',
        text: r'Lovely shelf. Would you consider $140? Happy to pick up whenever suits.',
        why: 'Low pressure, keeps rapport, still anchors low.',
      ),
      DealLineDto(
        intent: 'counter',
        text: r"I hear you. If $160 works, I'm ready whenever you are.",
        why: 'Soft counter that leaves the seller in control of timing.',
      ),
      DealLineDto(
        intent: 'close',
        text: r"Great, $160 it is. Thank you — I'll message when I'm on my way.",
        why: 'Gracious close that reduces the chance of a back-out.',
      ),
    ],
  };

  @override
  Future<UploadScreenshotResultDto> uploadScreenshot(final String filePath) async {
    _logger.i('Mock upload screenshot: $filePath');
    await Future<void>.delayed(_uploadDelay);
    // Mock always succeeds so user can tap Get More and see a reply
    return UploadScreenshotResultDto(id: 'mock_${filePath.hashCode}');
  }

  @override
  Future<DealReplyDto> getDealReply({
    required final List<String> uploadedIds,
    required final String locale,
    final String? keyword,
    final String? vibe,
    final String? conversationId,
  }) async {
    _logger.i('Mock getDealReply ids: $uploadedIds keyword: $keyword locale: $locale vibe: $vibe');
    await Future<void>.delayed(_getReplyDelay);
    return buildReply(keyword: keyword, vibe: vibe);
  }

  /// Synchronous body of [getDealReply] (no delay) – handy for tests.
  /// Spanish (and any other locale) reuses the English copy.
  static DealReplyDto buildReply({final String? keyword, final String? vibe}) {
    final trimmedKeyword = keyword?.trim() ?? '';
    if (trimmedKeyword.toLowerCase() == failKeyword) {
      throw StateError('QA hook: keyword "$failKeyword" forces a reply failure');
    }
    final lines = replySets[vibe] ?? replySets[defaultVibe]!;
    final seen = trimmedKeyword.isEmpty ? seeing : '$seeing ($trimmedKeyword)';
    return DealReplyDto(seeing: seen, lines: lines);
  }
}
