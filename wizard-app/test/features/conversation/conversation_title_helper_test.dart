import 'package:flutter_test/flutter_test.dart';

import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/conversation/domain/helpers/conversation_title_helper.dart';

void main() {
  final created = DateTime(2026, 9);

  Conversation express({String? title, String? seeing}) => Conversation(
        id: 'e1',
        type: ConversationType.express,
        createdAt: created,
        title: title,
        seeing: seeing,
      );

  Conversation pro(List<ProDealCloserMessage> messages, {String? title}) => Conversation(
        id: 'p1',
        type: ConversationType.proDealCloser,
        createdAt: created,
        title: title,
        messages: messages,
      );

  group('ConversationTitleHelper.titleOf', () {
    test('explicit title wins for both types and is whitespace-normalized', () {
      expect(ConversationTitleHelper.titleOf(express(title: '  IKEA   Kallax ', seeing: 'x · y')),
          'IKEA Kallax');
      expect(
        ConversationTitleHelper.titleOf(pro(
          const [ProDealCloserMessage(text: 'hello')],
          title: 'Road bike',
        )),
        'Road bike',
      );
    });

    test('express: uses the seeing strip before the first "·"', () {
      expect(
        ConversationTitleHelper.titleOf(express(seeing: 'IKEA Kallax shelf · \$180 · Facebook')),
        'IKEA Kallax shelf',
      );
    });

    test('express: blank title and seeing fall back to "Screenshot deal"', () {
      expect(ConversationTitleHelper.titleOf(express(title: '   ')), 'Screenshot deal');
      expect(ConversationTitleHelper.titleOf(express(seeing: ' · \$180')), 'Screenshot deal');
      expect(
        ConversationTitleHelper.titleOf(express(), expressFallback: 'Trato por captura'),
        'Trato por captura',
      );
    });

    test('pro: first user message, skipping wizard messages', () {
      final c = pro(const [
        ProDealCloserMessage(text: "What's the deal about?", isWizard: true),
        ProDealCloserMessage(text: '   '),
        ProDealCloserMessage(text: 'Road bike, 56cm, seller wants 600'),
      ]);
      expect(ConversationTitleHelper.titleOf(c), 'Road bike, 56cm, seller wants 600');
    });

    test('pro: long first message is truncated with an ellipsis', () {
      final c = pro(const [
        ProDealCloserMessage(text: 'A very long opening message that keeps going on and on'),
      ]);
      final title = ConversationTitleHelper.titleOf(c, maxLength: 20);
      expect(title.length, lessThanOrEqualTo(20));
      expect(title.endsWith('…'), isTrue);
      expect(title, 'A very long opening…');
    });

    test('pro: no user messages fall back to "Untitled chat deal"', () {
      final c = pro(const [ProDealCloserMessage(text: 'Hi there', isWizard: true)]);
      expect(ConversationTitleHelper.titleOf(c), 'Untitled chat deal');
      expect(ConversationTitleHelper.titleOf(pro(const []), proFallback: 'Chat sin título'),
          'Chat sin título');
    });
  });

  group('ConversationTitleHelper.fromSeeing', () {
    test('returns null for null / blank / empty head', () {
      expect(ConversationTitleHelper.fromSeeing(null), isNull);
      expect(ConversationTitleHelper.fromSeeing('   '), isNull);
      expect(ConversationTitleHelper.fromSeeing('· \$100'), isNull);
    });

    test('returns whole string when there is no separator', () {
      expect(ConversationTitleHelper.fromSeeing('Stroller bundle'), 'Stroller bundle');
    });
  });
}
