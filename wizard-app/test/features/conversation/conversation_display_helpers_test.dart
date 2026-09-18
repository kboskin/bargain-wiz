import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/conversation/domain/helpers/conversation_date_formatter.dart';
import 'package:appwizard/features/conversation/domain/helpers/conversation_price_helper.dart';
import 'package:appwizard/features/conversation/domain/repositories/conversation_repository.dart';

class _InMemoryRepository implements ConversationRepository {
  _InMemoryRepository(List<Conversation> seed) : items = [...seed];

  final List<Conversation> items;
  bool failSave = false;

  @override
  Future<Either<Failure, List<Conversation>>> getConversations() async => Right(List.of(items));

  @override
  Future<Either<Failure, void>> saveConversation(Conversation conversation) async {
    if (failSave) return const Left(CacheFailure('disk full'));
    items
      ..removeWhere((c) => c.id == conversation.id)
      ..insert(0, conversation);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteConversation(String id) async {
    items.removeWhere((c) => c.id == id);
    return const Right(null);
  }

}

void main() {
  group('ConversationDateFormatter', () {
    final now = DateTime(2026, 9, 11, 15, 30);

    test('same calendar day is Today regardless of time', () {
      expect(ConversationDateFormatter.format(DateTime(2026, 9, 11, 0, 5), now: now), 'Today');
      expect(ConversationDateFormatter.format(DateTime(2026, 9, 11, 23, 59), now: now), 'Today');
    });

    test('previous calendar day is Yesterday', () {
      expect(ConversationDateFormatter.format(DateTime(2026, 9, 10, 23), now: now), 'Yesterday');
    });

    test('older dates use the short month-day format', () {
      expect(ConversationDateFormatter.format(DateTime(2026, 9, 8), now: now), 'Sep 8');
      expect(ConversationDateFormatter.format(DateTime(2025, 12, 25), now: now), 'Dec 25');
    });

    test('custom labels are used for Today / Yesterday', () {
      expect(
        ConversationDateFormatter.format(DateTime(2026, 9, 11), now: now, today: 'Hoy'),
        'Hoy',
      );
      expect(
        ConversationDateFormatter.format(DateTime(2026, 9, 10), now: now, yesterday: 'Ayer'),
        'Ayer',
      );
    });

    test('unknown locale falls back instead of throwing', () {
      expect(
        () => ConversationDateFormatter.monthDay(DateTime(2026, 9, 8), locale: 'xx_YY'),
        returnsNormally,
      );
    });
  });

  group('ConversationPriceHelper.priceLine', () {
    Conversation build(ConversationType type, {String? before, String? after}) => Conversation(
          id: 'x',
          type: type,
          createdAt: DateTime(2026),
          priceBefore: before,
          priceAfter: after,
        );

    test('both prices render as "before → after"', () {
      expect(
        ConversationPriceHelper.priceLine(build(ConversationType.express, before: '\$420', after: '\$365')),
        '\$420 → \$365',
      );
    });

    test('only one price renders alone', () {
      expect(ConversationPriceHelper.priceLine(build(ConversationType.express, before: '\$180')), '\$180');
      expect(ConversationPriceHelper.priceLine(build(ConversationType.proDealCloser, after: '\$90')), '\$90');
    });

    test('pro without prices is a text deal; express without prices has no line', () {
      expect(ConversationPriceHelper.priceLine(build(ConversationType.proDealCloser)), 'Text deal');
      expect(
        ConversationPriceHelper.priceLine(build(ConversationType.proDealCloser), textDealLabel: 'Trato por chat'),
        'Trato por chat',
      );
      expect(ConversationPriceHelper.priceLine(build(ConversationType.express, before: '  ')), isNull);
    });
  });

  group('ConversationRepositoryX', () {
    final a = Conversation(id: 'a', type: ConversationType.express, createdAt: DateTime(2026, 9));
    final b = Conversation(
      id: 'b',
      type: ConversationType.proDealCloser,
      createdAt: DateTime(2026, 9, 2),
      priceBefore: '\$600',
    );

    test('findById returns the match or null', () async {
      final repo = _InMemoryRepository([a, b]);
      expect((await repo.findById('b')).getOrElse(() => null), b);
      expect((await repo.findById('zzz')).getOrElse(() => a), isNull);
    });

    test('updateStatus persists status and final price, keeping other fields', () async {
      final repo = _InMemoryRepository([a, b]);
      final result = await repo.updateStatus('b', ConversationStatus.won, priceAfter: '\$520');

      final updated = result.getOrElse(() => throw StateError('expected success'));
      expect(updated.status, ConversationStatus.won);
      expect(updated.priceAfter, '\$520');
      expect(updated.priceBefore, '\$600');
      expect(updated.createdAt, b.createdAt);
      expect(repo.items.singleWhere((c) => c.id == 'b').status, ConversationStatus.won);
      expect(repo.items.singleWhere((c) => c.id == 'a').status, ConversationStatus.open);
    });

    test('updateStatus without a price leaves the stored price untouched', () async {
      final repo = _InMemoryRepository([b.copyWith(priceAfter: '\$550')]);
      final result = await repo.updateStatus('b', ConversationStatus.lost);
      expect(result.getOrElse(() => throw StateError('expected success')).priceAfter, '\$550');
    });

    test('updateStatus fails for unknown ids and propagates save failures', () async {
      final repo = _InMemoryRepository([a]);
      expect((await repo.updateStatus('nope', ConversationStatus.won)).isLeft(), isTrue);

      repo.failSave = true;
      final failed = await repo.updateStatus('a', ConversationStatus.won);
      expect(failed.fold((f) => f.message, (_) => 'ok'), 'disk full');
    });
  });
}
