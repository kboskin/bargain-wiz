import 'dart:async';

import 'package:appwizard/core/services/auth_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/conversation/data/datasources/fake_conversations_backend.dart';
import 'package:appwizard/features/conversation/data/models/conversation_api_models.dart';
import 'package:appwizard/features/conversation/data/repositories/conversation_repository_impl.dart';
import 'package:appwizard/features/conversation/domain/conversation_changes.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuth implements AuthService {
  _FakeAuth(this._uid);

  String? _uid;
  final StreamController<String?> _uids = StreamController.broadcast();

  @override
  Future<String?> ensureUid() async => _uid;

  @override
  Stream<String?> get uidChanges => _uids.stream;

  void switchTo(String? uid) {
    _uid = uid;
    _uids.add(uid);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Counts uid lookups on top of another fake.
class _CountingAuth implements AuthService {
  _CountingAuth(this._inner, this._onLookup);

  final _FakeAuth _inner;
  final void Function() _onLookup;

  @override
  Future<String?> ensureUid() {
    _onLookup();
    return _inner.ensureUid();
  }

  @override
  Stream<String?> get uidChanges => _inner.uidChanges;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const _profile = ConversationProfile(vibe: 'friendly', push: 60, locale: 'en');

void main() {
  late FakeConversationsBackend backend;
  late _FakeAuth auth;
  late ConversationChanges changes;
  late ConversationRepositoryImpl repo;

  setUp(() {
    backend = FakeConversationsBackend(replyDelay: Duration.zero, optionsDelay: Duration.zero);
    auth = _FakeAuth('u1');
    changes = ConversationChanges();
    repo = ConversationRepositoryImpl(api: backend, stream: backend, auth: auth, logger: AppLogger(null), changes: changes);
  });

  tearDown(() => repo.dispose());

  Future<String> createDeal(String text, {String requestId = 'r1'}) async {
    final response = await backend.create(CreateConversationRequest(
      type: 'pro',
      requestId: requestId,
      profile: _profile,
      text: text,
    ));
    await pumpEventQueue();
    return response.conversationId;
  }

  Future<List<Conversation>> list() async => (await repo.getConversations()).getOrElse(() => const []);

  test('serves the listener snapshots and bumps ConversationChanges on each one', () async {
    var bumps = 0;
    changes.addListener(() => bumps++);

    expect(await list(), isEmpty);
    await createDeal('Kallax 180');

    final conversations = await list();
    expect(conversations.single.type, ConversationType.proDealCloser);
    expect(conversations.single.title, 'Kallax 180');
    expect(bumps, greaterThan(0));
  });

  test('saveConversation patches history metadata (updateStatus goes through it)', () async {
    final id = await createDeal('Kallax 180');

    final result = await repo.updateStatus(id, ConversationStatus.won, priceAfter: r'$150');

    expect(result.isRight(), isTrue);
    final stored = backend.conversations.single;
    expect(stored.status, ConversationStatus.won);
    expect(stored.priceAfter, r'$150');
    expect((await list()).single.status, ConversationStatus.won);
  });

  test('deleteConversation archives: the row leaves the list, the backend keeps the deal', () async {
    final first = await createDeal('one', requestId: 'r1');
    await createDeal('two', requestId: 'r2');
    expect(await list(), hasLength(2));

    final result = await repo.deleteConversation(first);
    await pumpEventQueue();

    expect(result.isRight(), isTrue);
    expect(backend.conversations.map((c) => c.id), isNot(contains(first)));
    expect(backend.archived, {first});
    expect(backend.messagesOf(first), isNotEmpty); // nothing destroyed
    expect((await list()).map((c) => c.id), isNot(contains(first)));
  });

  test('without a uid the repository stays quiet: no change notifications, no retry loop', () async {
    final offline = _FakeAuth(null);
    var bumps = 0;
    var lookups = 0;
    changes.addListener(() => bumps++);
    final quiet = ConversationRepositoryImpl(
      api: backend,
      stream: backend,
      auth: _CountingAuth(offline, () => lookups++),
      logger: AppLogger(null),
      changes: changes,
    );

    expect((await quiet.getConversations()).getOrElse(() => const []), isEmpty);
    expect((await quiet.getConversations()).getOrElse(() => const []), isEmpty);

    expect(bumps, 0);
    expect(lookups, 2); // one lookup per call, nothing recursive
    await quiet.dispose();
  });

  test('losing the uid (sign-out before the anonymous re-sign-in) clears the list', () async {
    await createDeal('Kallax 180');
    expect(await list(), hasLength(1));

    auth.switchTo(null);
    await pumpEventQueue();

    expect(await list(), isEmpty);
  });
}
