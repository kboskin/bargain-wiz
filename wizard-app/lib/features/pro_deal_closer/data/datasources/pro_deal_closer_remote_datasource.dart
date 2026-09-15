import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';

/// Wizard reply DTO.
class WizardReplyDto {
  const WizardReplyDto({required this.text});

  final String text;
}

/// One option line DTO (`{text, intent, why}`).
class DealOptionDto {
  const DealOptionDto({required this.text, this.intent, this.why});

  final String text;
  /// "opener" | "counter" | "close"
  final String? intent;
  final String? why;
}

/// Remote data source for Pro Deal Closer. Implement with mock or real HTTP client.
abstract class ProDealCloserRemoteDataSource {
  Future<WizardReplyDto> getReply({
    required List<ProDealCloserMessage> history,
    required String vibe,
    required String locale,
    bool regenerate = false,
  });

  Future<List<DealOptionDto>> getOptions({
    required List<ProDealCloserMessage> history,
    required String vibe,
    required String locale,
  });
}

/// Mock implementation mirroring the design prototype (`proReply` / `REPLY_SETS`):
/// canned reply per vibe (typing 1.3 s), "(Regenerated)" suffix on redo,
/// three intent-tagged options per vibe (0.8 s).
class MockProDealCloserRemoteDataSource implements ProDealCloserRemoteDataSource {
  MockProDealCloserRemoteDataSource(
    this._logger, {
    this.replyDelay = const Duration(milliseconds: 1300),
    this.optionsDelay = const Duration(milliseconds: 800),
  });

  final AppLogger _logger;
  final Duration replyDelay;
  final Duration optionsDelay;

  static const String defaultVibe = 'friendly';
  static const String regeneratedSuffix = ' (Regenerated)';

  /// Reply paragraphs per vibe, verbatim from the prototype.
  static const Map<String, String> replyTexts = {
    'friendly':
        "Nice find. Sellers usually list 15–25% above what they'll take, so a friendly \$140 with same-day pickup is a strong open. Want me to write it?",
    'no_nonsense':
        "Open at \$140 cash, pickup today. Don't explain, don't apologize. If they push back, hold at \$160 max.",
    'tactical':
        'Comparable Kallax units went for \$130–150 this week. Anchor at \$140 with that data, then trade a fast pickup for a \$160 ceiling.',
    'quiet_closer':
        "Keep it warm and low pressure: ask if they'd consider \$140 and offer flexible pickup. Most sellers meet you partway without any friction.",
  };

  /// Option sets per vibe, verbatim from the prototype `REPLY_SETS`.
  static const Map<String, List<DealOptionDto>> optionSets = {
    'friendly': [
      DealOptionDto(
        intent: 'opener',
        text: 'Hi! Is the Kallax still available? I could pick it up today if \$140 works for you.',
        why: 'Warm open, signals a fast easy sale, anchors 22% under ask.',
      ),
      DealOptionDto(
        intent: 'counter',
        text: 'Totally understand. Could you do \$160 if I bring cash tonight and handle the loading?',
        why: 'Concedes a little while adding certainty and effort on your side.',
      ),
      DealOptionDto(
        intent: 'close',
        text: '\$160 sounds good — what time works for pickup today?',
        why: 'Assumes the yes and moves straight to logistics.',
      ),
    ],
    'no_nonsense': [
      DealOptionDto(
        intent: 'opener',
        text: 'Still available? \$140 cash, pickup today.',
        why: 'Short and decisive. Sellers on Marketplace respond to speed.',
      ),
      DealOptionDto(
        intent: 'counter',
        text: '\$160 is my max. I can be there in an hour.',
        why: "A firm ceiling plus immediacy removes the seller's reason to wait.",
      ),
      DealOptionDto(
        intent: 'close',
        text: 'Deal at \$160. Send the address.',
        why: 'Closes without reopening price.',
      ),
    ],
    'tactical': [
      DealOptionDto(
        intent: 'opener',
        text: 'Two identical Kallax units sold this week for \$130–150 in this area. Would you take \$140?',
        why: 'Anchors with comparable data rather than opinion.',
      ),
      DealOptionDto(
        intent: 'counter',
        text: 'Given the scuff on the corner and the retail price is \$179 new, \$160 is fair for both of us.',
        why: 'Names a flaw and the new price to frame the counter as reasonable.',
      ),
      DealOptionDto(
        intent: 'close',
        text: "Let's lock in \$160. I'll bring exact cash and pick up at your convenience.",
        why: 'Removes friction and rewards the agreement.',
      ),
    ],
    'quiet_closer': [
      DealOptionDto(
        intent: 'opener',
        text: 'Lovely shelf. Would you consider \$140? Happy to pick up whenever suits.',
        why: 'Low pressure, keeps rapport, still anchors low.',
      ),
      DealOptionDto(
        intent: 'counter',
        text: "I hear you. If \$160 works, I'm ready whenever you are.",
        why: 'Soft counter that leaves the seller in control of timing.',
      ),
      DealOptionDto(
        intent: 'close',
        text: "Great, \$160 it is. Thank you — I'll message when I'm on my way.",
        why: 'Gracious close that reduces the chance of a back-out.',
      ),
    ],
  };

  @override
  Future<WizardReplyDto> getReply({
    required List<ProDealCloserMessage> history,
    required String vibe,
    required String locale,
    bool regenerate = false,
  }) async {
    _logger.i(
      'Mock Pro getReply history: ${history.length} vibe: $vibe locale: $locale regenerate: $regenerate',
    );
    await Future<void>.delayed(replyDelay);
    final text = replyTexts[vibe] ?? replyTexts[defaultVibe]!;
    return WizardReplyDto(text: regenerate ? '$text$regeneratedSuffix' : text);
  }

  @override
  Future<List<DealOptionDto>> getOptions({
    required List<ProDealCloserMessage> history,
    required String vibe,
    required String locale,
  }) async {
    _logger.i('Mock Pro getOptions history: ${history.length} vibe: $vibe locale: $locale');
    await Future<void>.delayed(optionsDelay);
    return optionSets[vibe] ?? optionSets[defaultVibe]!;
  }
}
