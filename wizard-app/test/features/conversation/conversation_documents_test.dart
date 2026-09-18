import 'package:appwizard/features/conversation/data/models/conversation_documents.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter_test/flutter_test.dart';

void main() {
  final created = DateTime.utc(2026, 9, 17, 12);
  final updated = DateTime.utc(2026, 9, 17, 13);

  test('maps an express conversation document', () {
    final conversation = ConversationDocuments.conversation('c1', {
      'type': 'express',
      'title': 'IKEA Kallax · \$180',
      'status': 'won',
      'vibe': 'tactical',
      'marketplace': 'facebook',
      'price_before': '\$180',
      'price_after': '\$150',
      'preview': 'Is it still available?',
      'message_count': 2,
      'created_at': Timestamp.fromDate(created),
      'updated_at': Timestamp.fromDate(updated),
      'thumbnail': {'path': 'users/u1/conversations/c1/a.jpg', 'width': 800, 'height': 1200},
      'express': {
        'seeing': 'Kallax, slight scuff',
        'keyword': 'scuff',
        'lines': [
          {'intent': 'opener', 'text': 'Hi', 'why': 'w'},
          {'intent': 'counter', 'text': ''},
        ],
        'images': [
          {'path': 'users/u1/conversations/c1/a.jpg'},
          {'path': 'users/u1/conversations/c1/b.jpg'},
        ],
      },
    });

    expect(conversation.id, 'c1');
    expect(conversation.type, ConversationType.express);
    expect(conversation.title, 'IKEA Kallax · \$180');
    expect(conversation.status, ConversationStatus.won);
    expect(conversation.vibe, 'tactical');
    expect(conversation.priceAfter, '\$150');
    expect(conversation.preview, 'Is it still available?');
    expect(conversation.messageCount, 2);
    // Timestamp.toDate() is local time; compare instants.
    expect(conversation.createdAt.isAtSameMomentAs(created), isTrue);
    expect(conversation.updatedAt!.isAtSameMomentAs(updated), isTrue);
    expect(conversation.sortedAt.isAtSameMomentAs(updated), isTrue);
    expect(conversation.thumbnailStoragePath, 'users/u1/conversations/c1/a.jpg');
    expect(conversation.thumbnailPath, 'users/u1/conversations/c1/a.jpg');
    expect(conversation.screenshotPaths, ['users/u1/conversations/c1/a.jpg', 'users/u1/conversations/c1/b.jpg']);
    expect(conversation.seeing, 'Kallax, slight scuff');
    expect(conversation.keyword, 'scuff');
    expect(conversation.replyLines.map((l) => l.text), ['Hi']); // empty line dropped
    expect(conversation.replyLines.single.intent, DealIntent.opener);
    expect(conversation.isTyping, isFalse);
  });

  test('maps a pro conversation with an active turn and tolerates missing fields', () {
    final conversation = ConversationDocuments.conversation('c2', {
      'type': 'pro',
      'active_turn': {'message_id': 'm2', 'request_id': 'r1'},
    });

    expect(conversation.type, ConversationType.proDealCloser);
    expect(conversation.isTyping, isTrue);
    expect(conversation.status, ConversationStatus.open);
    expect(conversation.title, isNull);
    expect(conversation.screenshotPaths, isEmpty);
    expect(conversation.thumbnailPath, isNull);
    expect(conversation.messageCount, 0);
  });

  test('maps wizard and user message documents', () {
    final pending = ConversationDocuments.message('m2', {
      'role': 'wizard',
      'text': '',
      'status': 'pending',
      'request_id': 'r1',
      'seq': 2,
    });
    expect(pending.isWizard, isTrue);
    expect(pending.isPending, isTrue);
    expect(pending.requestId, 'r1');
    expect(pending.seq, 2);

    final failed = ConversationDocuments.message('m4', {
      'role': 'wizard',
      'status': 'failed',
      'error': {'code': 'UPSTREAM_ERROR', 'message': 'The wizard could not answer. Try again.'},
      'revision': 1,
    });
    expect(failed.isFailed, isTrue);
    expect(failed.errorMessage, 'The wizard could not answer. Try again.');
    expect(failed.revision, 1);

    final user = ConversationDocuments.message('m1', {
      'role': 'user',
      'text': 'They ask 180',
      'images': [
        {'path': 'users/u1/conversations/c1/x.jpg', 'width': 640, 'height': 960, 'bytes': 12345},
      ],
      'lines': [
        {'intent': 'close', 'text': 'Deal at 160'},
      ],
      'seq': 1,
    });
    expect(user.isUser, isTrue);
    expect(user.status, MessageStatus.done);
    expect(user.attachments.single.storagePath, 'users/u1/conversations/c1/x.jpg');
    expect(user.attachments.single.width, 640);
    expect(user.displayPaths, ['users/u1/conversations/c1/x.jpg']);
    expect(user.options.single.intent, DealIntent.close);
  });
}
