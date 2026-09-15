import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/pro_deal_closer/domain/entities/pro_conversation_title.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProConversationTitle.derive', () {
    test('returns the untitled placeholder when there are no user texts', () {
      expect(ProConversationTitle.derive(const []), 'Untitled chat deal');
      expect(
        ProConversationTitle.derive(const [
          ProDealCloserMessage(text: "What's the deal about?", isWizard: true),
          ProDealCloserMessage(text: '', attachmentPaths: ['/a.png']),
        ]),
        'Untitled chat deal',
      );
    });

    test('uses the first user text, skipping wizard messages', () {
      expect(
        ProConversationTitle.derive(const [
          ProDealCloserMessage(text: 'Wizard greeting', isWizard: true),
          ProDealCloserMessage(text: 'Kallax shelf for \$180'),
          ProDealCloserMessage(text: 'Second line'),
        ]),
        'Kallax shelf for \$180',
      );
    });

    test('collapses whitespace and newlines', () {
      expect(
        ProConversationTitle.derive(const [ProDealCloserMessage(text: '  Road\n bike,   56cm ')]),
        'Road bike, 56cm',
      );
    });

    test('truncates long texts to ~40 chars on a word boundary with an ellipsis', () {
      const text = "They're asking \$180 for a Kallax shelf, slightly scuffed";
      final title = ProConversationTitle.derive(const [ProDealCloserMessage(text: text)]);

      expect(title.endsWith('…'), isTrue);
      expect(title.length, lessThanOrEqualTo(ProConversationTitle.maxLength + 1));
      expect(title, "They're asking \$180 for a Kallax shelf,…");
    });

    test('truncate falls back to a hard cut when there is no usable space', () {
      final long = 'a' * 60;
      expect(ProConversationTitle.truncate(long), '${'a' * 40}…');
      expect(ProConversationTitle.truncate('short'), 'short');
      expect(ProConversationTitle.truncate('x' * 40), 'x' * 40);
    });
  });
}
