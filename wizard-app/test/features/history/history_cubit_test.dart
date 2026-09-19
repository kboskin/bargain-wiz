import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:appwizard/features/history/presentation/cubit/history_cubit.dart';
import 'package:appwizard/features/history/presentation/cubit/history_state.dart';

class FakeConversationRepository implements ConversationRepository {
  FakeConversationRepository(List<Conversation> seed) : items = [...seed];

  final List<Conversation> items;
  bool failLoad = false;
  bool failDelete = false;

  @override
  Future<Either<Failure, List<Conversation>>> getConversations() async {
    if (failLoad) return const Left(CacheFailure('no storage'));
    return Right(List.of(items));
  }

  @override
  Future<Either<Failure, void>> saveConversation(Conversation conversation) async {
    items
      ..removeWhere((c) => c.id == conversation.id)
      ..insert(0, conversation);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteConversation(String id) async {
    if (failDelete) return const Left(CacheFailure('locked'));
    items.removeWhere((c) => c.id == id);
    return const Right(null);
  }

}

void main() {
  final kallax = Conversation(
    id: 'kallax',
    type: ConversationType.express,
    createdAt: DateTime(2026, 9, 11),
    title: 'IKEA Kallax shelf',
    marketplace: 'facebook',
    priceBefore: '\$180',
  );
  final iphone = Conversation(
    id: 'iphone',
    type: ConversationType.express,
    createdAt: DateTime(2026, 9, 10),
    seeing: 'iPhone 13, 128GB · \$420 · eBay',
    marketplace: 'ebay',
    status: ConversationStatus.won,
    priceBefore: '\$420',
    priceAfter: '\$365',
  );
  final bike = Conversation(
    id: 'bike',
    type: ConversationType.proDealCloser,
    createdAt: DateTime(2026, 9, 8),
    messages: const [ProDealCloserMessage(text: 'Road bike, 56cm')],
    marketplace: 'olx',
    status: ConversationStatus.lost,
  );

  late FakeConversationRepository repo;
  late ValueNotifier<int> changes;
  late HistoryCubit cubit;

  setUp(() {
    // Seeded oldest-first on purpose: the cubit must sort newest first.
    repo = FakeConversationRepository([bike, iphone, kallax]);
    changes = ValueNotifier<int>(0);
    cubit = HistoryCubit(
      repo,
      changes: changes,
      // What the marketplace screen's options are labelled, as the page supplies them.
      marketplaceLabels: () => const {
        'facebook': 'Facebook Marketplace',
        'ebay': 'eBay',
        'olx': 'OLX',
      },
    );
  });

  tearDown(() async {
    await cubit.close();
    changes.dispose();
  });

  group('load', () {
    test('sorts newest first and becomes ready', () async {
      await cubit.load();
      expect(cubit.state.loadStatus, HistoryLoadStatus.ready);
      expect(cubit.state.conversations.map((c) => c.id), ['kallax', 'iphone', 'bike']);
      expect(cubit.state.visible.length, 3);
      expect(cubit.state.isFiltering, isFalse);
    });

    test('reports failures without dropping the previous list', () async {
      await cubit.load();
      repo.failLoad = true;
      await cubit.load();
      expect(cubit.state.loadStatus, HistoryLoadStatus.failure);
      expect(cubit.state.errorMessage, 'no storage');
      expect(cubit.state.conversations.length, 3);
    });

    test('reloads when the change notifier fires', () async {
      await cubit.load();
      repo.items.add(Conversation(
        id: 'new',
        type: ConversationType.express,
        createdAt: DateTime(2026, 9, 12),
      ));
      changes.value++;
      await pumpEventQueue();
      expect(cubit.state.conversations.first.id, 'new');
    });
  });

  group('filter', () {
    test('status chips narrow the visible rows', () async {
      await cubit.load();
      cubit.setFilter(HistoryFilter.won);
      expect(cubit.state.visible.map((c) => c.id), ['iphone']);
      cubit.setFilter(HistoryFilter.lost);
      expect(cubit.state.visible.map((c) => c.id), ['bike']);
      cubit.setFilter(HistoryFilter.open);
      expect(cubit.state.visible.map((c) => c.id), ['kallax']);
      cubit.setFilter(HistoryFilter.all);
      expect(cubit.state.visible.length, 3);
      expect(cubit.state.isFiltering, isFalse);
    });
  });

  group('search', () {
    test('matches explicit and auto titles case-insensitively', () async {
      await cubit.load();
      cubit.search('KALLAX');
      expect(cubit.state.visible.map((c) => c.id), ['kallax']);
      cubit.search('iphone 13');
      expect(cubit.state.visible.map((c) => c.id), ['iphone']);
      cubit.search('road bike');
      expect(cubit.state.visible.map((c) => c.id), ['bike']);
    });

    test('matches the marketplace label and raw value', () async {
      await cubit.load();
      cubit.search('facebook marketplace');
      expect(cubit.state.visible.map((c) => c.id), ['kallax']);
      cubit.search('olx');
      expect(cubit.state.visible.map((c) => c.id), ['bike']);
    });

    test('combines with the status filter and flags empty results as filtering', () async {
      await cubit.load();
      cubit
        ..setFilter(HistoryFilter.won)
        ..search('ebay');
      expect(cubit.state.visible.map((c) => c.id), ['iphone']);
      cubit.search('nothing here');
      expect(cubit.state.visible, isEmpty);
      expect(cubit.state.hasAny, isTrue);
      expect(cubit.state.isFiltering, isTrue);
    });

    test('HistoryState.apply is pure and ignores surrounding whitespace', () {
      final rows = HistoryState.apply([kallax, iphone, bike], query: '  ebay  ');
      expect(rows.map((c) => c.id), ['iphone']);
      expect(HistoryState.apply([kallax], filter: HistoryFilter.lost), isEmpty);
    });
  });

  group('delete', () {
    test('removes optimistically and persists', () async {
      await cubit.load();
      final ok = await cubit.delete('iphone');
      expect(ok, isTrue);
      expect(cubit.state.conversations.map((c) => c.id), ['kallax', 'bike']);
      expect(repo.items.map((c) => c.id), isNot(contains('iphone')));
    });

    test('restores the row when the repository fails', () async {
      await cubit.load();
      repo.failDelete = true;
      final ok = await cubit.delete('iphone');
      expect(ok, isFalse);
      expect(cubit.state.conversations.length, 3);
      expect(cubit.state.errorMessage, 'locked');
    });
  });

  group('updateStatus', () {
    test('updates the row in place with status and final price', () async {
      await cubit.load();
      final ok = await cubit.updateStatus('kallax', ConversationStatus.won, priceAfter: '\$140');
      expect(ok, isTrue);
      final row = cubit.state.conversations.singleWhere((c) => c.id == 'kallax');
      expect(row.status, ConversationStatus.won);
      expect(row.priceAfter, '\$140');
      expect(row.priceBefore, '\$180');
      expect(repo.items.singleWhere((c) => c.id == 'kallax').status, ConversationStatus.won);
      // Order is by createdAt, not by storage position.
      expect(cubit.state.conversations.map((c) => c.id), ['kallax', 'iphone', 'bike']);
    });

    test('reports unknown ids as an error', () async {
      await cubit.load();
      final ok = await cubit.updateStatus('ghost', ConversationStatus.lost);
      expect(ok, isFalse);
      expect(cubit.state.errorMessage, contains('ghost'));
    });
  });
}
