import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/conversation/data/mappers/conversation_mapper.dart';
import 'package:appwizard/features/conversation/data/mappers/conversation_type_mapper.dart';
import 'package:appwizard/features/conversation/data/models/conversation_model.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';

void main() {
  final mapper = ConversationMapper(ConversationTypeMapper(), AppLogger(null));

  group('ConversationMapper round trip', () {
    test('express conversation with history metadata survives model → json → entity', () {
      final original = Conversation(
        id: 'ex-1',
        type: ConversationType.express,
        screenshotPaths: const ['/tmp/a.png', '/tmp/b.png'],
        replyLines: const [
          DealLine(text: 'Would you take \$140?', intent: DealIntent.opener, why: 'Anchors low'),
          DealLine(text: 'Deal at \$150 today.', intent: DealIntent.close),
        ],
        keyword: 'shelf',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1757500000000),
        title: 'IKEA Kallax shelf',
        marketplace: 'facebook',
        status: ConversationStatus.won,
        priceBefore: '\$180',
        priceAfter: '\$140',
        seeing: 'IKEA Kallax shelf · \$180 · Facebook',
        vibe: 'friendly',
      );

      final json = jsonDecode(jsonEncode(mapper.toModel(original).toJson())) as Map<String, dynamic>;
      final restored = mapper.toEntity(ConversationModel.fromJson(json));

      expect(restored, original);
      expect(json['status'], 'won');
      expect(json['type'], 'express');
      expect(json['screenshots'], ['/tmp/a.png', '/tmp/b.png']);
    });

    test('pro conversation with messages, attachments and options round-trips', () {
      final original = Conversation(
        id: 'pro-1',
        type: ConversationType.proDealCloser,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1757400000000),
        messages: const [
          ProDealCloserMessage(text: "What's the deal about?", isWizard: true),
          ProDealCloserMessage(text: 'Road bike 56cm', attachmentPaths: ['/tmp/bike.jpg']),
          ProDealCloserMessage(
            text: 'Try this:',
            isWizard: true,
            options: [DealLine(text: 'Is \$500 doable?', intent: DealIntent.counter)],
          ),
        ],
        marketplace: 'olx',
        status: ConversationStatus.lost,
        priceBefore: '\$600',
        vibe: 'tactical',
      );

      final json = jsonDecode(jsonEncode(mapper.toModel(original).toJson())) as Map<String, dynamic>;
      final restored = mapper.toEntity(ConversationModel.fromJson(json));

      expect(restored, original);
      expect(json['type'], 'pro_deal_closer');
      expect(restored.thumbnailPath, '/tmp/bike.jpg');
      expect(restored.title, isNull);
    });
  });

  group('ConversationMapper legacy JSON', () {
    test('records saved before the history metadata existed get defaults', () {
      final legacy = <String, dynamic>{
        'id': 'legacy-1',
        'type': 'express',
        'screenshots': ['/tmp/old.png'],
        'replyOptions': ['Hi, is this still available?'],
        'keyword': 'sofa',
        'createdAtMillis': 1700000000000,
      };

      final entity = mapper.toEntity(ConversationModel.fromJson(legacy));

      expect(entity.id, 'legacy-1');
      expect(entity.type, ConversationType.express);
      expect(entity.status, ConversationStatus.open);
      expect(entity.title, isNull);
      expect(entity.marketplace, isNull);
      expect(entity.priceBefore, isNull);
      expect(entity.priceAfter, isNull);
      expect(entity.seeing, isNull);
      expect(entity.vibe, isNull);
      expect(entity.messages, isEmpty);
      expect(entity.replyLines, isEmpty);
      expect(entity.effectiveLines.map((l) => l.text), ['Hi, is this still available?']);
      expect(entity.thumbnailPath, '/tmp/old.png');
      expect(entity.createdAt, DateTime.fromMillisecondsSinceEpoch(1700000000000));
    });

    test('missing id / createdAtMillis and unknown type do not throw', () {
      final entity = mapper.toEntity(ConversationModel.fromJson(<String, dynamic>{'type': 'weird'}));
      expect(entity.id, '');
      expect(entity.type, ConversationType.express);
      expect(entity.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
      expect(entity.status, ConversationStatus.open);
    });

    test('unknown status string falls back to open', () {
      expect(ConversationStatus.fromString('WON'), ConversationStatus.won);
      expect(ConversationStatus.fromString('lost'), ConversationStatus.lost);
      expect(ConversationStatus.fromString('archived'), ConversationStatus.open);
      expect(ConversationStatus.fromString(null), ConversationStatus.open);
    });
  });
}
