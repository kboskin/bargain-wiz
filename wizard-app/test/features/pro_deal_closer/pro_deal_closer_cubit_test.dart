import 'dart:async';

import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/pro_deal_closer/domain/entities/pro_conversation_title.dart';
import 'package:appwizard/features/pro_deal_closer/domain/entities/wizard_reply.dart';
import 'package:appwizard/features/pro_deal_closer/presentation/cubit/pro_deal_closer_cubit.dart';
import 'package:appwizard/features/pro_deal_closer/presentation/cubit/pro_deal_closer_state.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late FakeProDealCloserRepository repo;
  late FakeConversationRepository conversations;
  late ProDealCloserCubit cubit;

  ProDealCloserCubit build({String Function()? idGenerator}) => ProDealCloserCubit(
        repository: repo,
        conversationRepository: conversations,
        logger: testLogger(),
        uploadDelay: Duration.zero,
        idGenerator: idGenerator,
      );

  setUp(() {
    repo = FakeProDealCloserRepository();
    conversations = FakeConversationRepository();
    cubit = build();
  });

  tearDown(() => cubit.close());

  Future<void> startFresh({String vibe = 'friendly'}) => cubit.start(vibe: vibe, locale: 'en');

  group('start', () {
    test('fresh chat shows only the pinned greeting', () async {
      await startFresh();

      expect(cubit.state.status, ProDealCloserStatus.ready);
      expect(cubit.state.messages, hasLength(1));
      expect(cubit.state.messages.single.isWizard, isTrue);
      expect(cubit.state.messages.single.text, ProDealCloserCubit.greetingText);
      expect(cubit.state.messages.single.showActions, isFalse);
      expect(cubit.state.hasUserMessages, isFalse);
      expect(cubit.state.vibe, 'friendly');
      expect(cubit.state.locale, 'en');
    });

    test('restores a saved conversation: messages, options kept, actions hidden', () async {
      final createdAt = DateTime(2026, 9);
      conversations.store['c1'] = Conversation(
        id: 'c1',
        type: ConversationType.proDealCloser,
        createdAt: createdAt,
        status: ConversationStatus.won,
        vibe: 'tactical',
        messages: const [
          ProDealCloserMessage(text: ProDealCloserCubit.greetingText, isWizard: true),
          ProDealCloserMessage(text: 'They ask 180'),
          ProDealCloserMessage(
            text: 'Reply',
            isWizard: true,
            options: FakeProDealCloserRepository.options,
          ),
        ],
      );

      await cubit.start(conversationId: 'c1', vibe: 'friendly', locale: 'es');

      final s = cubit.state;
      expect(s.conversationId, 'c1');
      expect(s.createdAt, createdAt);
      expect(s.conversationStatus, ConversationStatus.won);
      expect(s.messages, hasLength(3));
      expect(s.messages.every((m) => m.restored), isTrue);
      expect(s.messages.every((m) => !m.showActions), isTrue);
      expect(s.messages.last.options, FakeProDealCloserRepository.options);
      // Current tone comes from the profile, not from the saved deal.
      expect(s.vibe, 'friendly');
    });

    test('prepends the greeting when a legacy save has no wizard messages', () async {
      conversations.store['legacy'] = Conversation(
        id: 'legacy',
        type: ConversationType.proDealCloser,
        createdAt: DateTime(2026),
        messages: const [ProDealCloserMessage(text: 'Only user text')],
      );

      await cubit.start(conversationId: 'legacy', vibe: 'friendly', locale: 'en');

      expect(cubit.state.messages, hasLength(2));
      expect(cubit.state.messages.first.text, ProDealCloserCubit.greetingText);
      expect(cubit.state.messages.first.restored, isTrue);
    });

    test('unknown conversation id starts fresh but keeps the id for saving', () async {
      await cubit.start(conversationId: 'missing', vibe: 'friendly', locale: 'en');

      expect(cubit.state.messages, hasLength(1));
      expect(cubit.state.conversationId, 'missing');
    });
  });

  group('sendText', () {
    test('appends the user bubble, shows typing, then the wizard reply with actions', () async {
      await startFresh();
      final states = <ProDealCloserState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.sendText('  They ask \$180 for a Kallax  ');
      await sub.cancel();

      final typing = states.firstWhere((s) => s.isTyping);
      expect(typing.messages, hasLength(2));
      expect(typing.messages.last.isUser, isTrue);
      expect(typing.messages.last.text, 'They ask \$180 for a Kallax');

      final done = cubit.state;
      expect(done.isTyping, isFalse);
      expect(done.messages, hasLength(3));
      expect(done.messages.last.isWizard, isTrue);
      expect(done.messages.last.text, 'Reply for friendly');
      expect(done.messages.last.showActions, isTrue);
      expect(done.messages.last.options, isEmpty);

      expect(repo.replyCalls, hasLength(1));
      expect(repo.replyCalls.single.vibe, 'friendly');
      expect(repo.replyCalls.single.regenerate, isFalse);
      expect(repo.replyCalls.single.history, hasLength(2));
    });

    test('ignores blank input', () async {
      await startFresh();
      await cubit.sendText('   ');
      expect(cubit.state.messages, hasLength(1));
      expect(repo.replyCalls, isEmpty);
    });

    test('uses the tone set via setVibe for subsequent replies', () async {
      await startFresh();
      cubit.setVibe('no_nonsense');

      await cubit.sendText('Hello');

      expect(repo.replyCalls.single.vibe, 'no_nonsense');
      expect(cubit.state.messages.last.text, 'Reply for no_nonsense');
    });

    test('failure stops typing and bumps errorCount', () async {
      await startFresh();
      repo.failure = const ServerFailure('boom');

      await cubit.sendText('Hello');

      expect(cubit.state.isTyping, isFalse);
      expect(cubit.state.errorCount, 1);
      expect(cubit.state.failure, const ServerFailure('boom'));
      expect(cubit.state.messages, hasLength(2));
    });
  });

  group('sendAttachments', () {
    test('uploading → read → typing → reply', () async {
      await startFresh();
      final states = <ProDealCloserState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.sendAttachments(['/a.png', '/b.png']);
      await sub.cancel();

      final uploading = states.first;
      expect(uploading.messages.last.attachmentPaths, ['/a.png', '/b.png']);
      expect(uploading.messages.last.isUploading, isTrue);
      expect(uploading.isTyping, isFalse);

      final typing = states.firstWhere((s) => s.isTyping);
      expect(typing.messages.last.isUploading, isFalse);

      expect(cubit.state.isTyping, isFalse);
      expect(cubit.state.messages, hasLength(3));
      expect(cubit.state.messages.last.isWizard, isTrue);
      expect(repo.replyCalls.single.history.last.attachmentPaths, ['/a.png', '/b.png']);
    });

    test('ignores an empty pick', () async {
      await startFresh();
      await cubit.sendAttachments(const []);
      expect(cubit.state.messages, hasLength(1));
    });
  });

  group('requestOptions', () {
    test('attaches 3 DealLines to the reply and hides the action row', () async {
      await startFresh();
      await cubit.sendText('Hello');
      final reply = cubit.state.messages.last;

      final future = cubit.requestOptions(reply.id);
      expect(cubit.state.messageById(reply.id)!.optionsLoading, isTrue);
      await future;

      final updated = cubit.state.messageById(reply.id)!;
      expect(updated.options, hasLength(3));
      expect(updated.options.map((o) => o.intent), [
        DealIntent.opener,
        DealIntent.counter,
        DealIntent.close,
      ]);
      expect(updated.options.first.why, 'why 1');
      expect(updated.showActions, isFalse);
      expect(updated.optionsLoading, isFalse);
      // History passed ends with the wizard reply the options belong to.
      expect(repo.optionsCalls.single.last.isWizard, isTrue);
      expect(repo.optionsCalls.single, hasLength(3));
    });

    test('failure clears loading and keeps the action row', () async {
      await startFresh();
      await cubit.sendText('Hello');
      final reply = cubit.state.messages.last;
      repo.failure = const NetworkFailure('offline');

      await cubit.requestOptions(reply.id);

      final updated = cubit.state.messageById(reply.id)!;
      expect(updated.options, isEmpty);
      expect(updated.optionsLoading, isFalse);
      expect(updated.showActions, isTrue);
      expect(cubit.state.errorCount, 1);
    });
  });

  group('redo', () {
    test('shows typing, then replaces the reply text and clears options', () async {
      await startFresh();
      await cubit.sendText('Hello');
      final reply = cubit.state.messages.last;
      await cubit.requestOptions(reply.id);
      expect(cubit.state.messageById(reply.id)!.options, isNotEmpty);

      final states = <ProDealCloserState>[];
      final sub = cubit.stream.listen(states.add);
      await cubit.redo(reply.id);
      await sub.cancel();

      expect(states.first.isTyping, isTrue);
      final updated = cubit.state.messageById(reply.id)!;
      expect(updated.text, 'Reply for friendly (Regenerated)');
      expect(updated.options, isEmpty);
      expect(updated.showActions, isTrue);
      expect(cubit.state.isTyping, isFalse);
      expect(cubit.state.messages, hasLength(3));

      final call = repo.replyCalls.last;
      expect(call.regenerate, isTrue);
      // History excludes the reply being regenerated.
      expect(call.history, hasLength(2));
      expect(call.history.last.isWizard, isFalse);
    });

    test('is a no-op for an unknown message id', () async {
      await startFresh();
      await cubit.redo('nope');
      expect(cubit.state.isTyping, isFalse);
      expect(repo.replyCalls, isEmpty);
    });
  });

  group('save', () {
    test('does nothing without a user message', () async {
      await startFresh();
      expect(await cubit.save(marketplace: 'ebay'), isFalse);
      expect(conversations.store, isEmpty);
    });

    test('persists type, title, vibe, marketplace and wizard messages with options', () async {
      cubit = build(idGenerator: () => 'generated-id');
      await startFresh(vibe: 'tactical');
      await cubit.sendText('They are asking \$180 for a Kallax shelf, slightly scuffed');
      await cubit.requestOptions(cubit.state.messages.last.id);

      expect(await cubit.save(marketplace: 'facebook'), isTrue);

      final saved = conversations.store['generated-id']!;
      expect(saved.type, ConversationType.proDealCloser);
      expect(saved.status, ConversationStatus.open);
      expect(saved.vibe, 'tactical');
      expect(saved.marketplace, 'facebook');
      expect(saved.title, ProConversationTitle.truncate('They are asking \$180 for a Kallax shelf, slightly scuffed'));
      expect(saved.messages, hasLength(3));
      expect(saved.messages.first.isWizard, isTrue);
      expect(saved.messages[1].text, 'They are asking \$180 for a Kallax shelf, slightly scuffed');
      expect(saved.messages.last.isWizard, isTrue);
      expect(saved.messages.last.options, FakeProDealCloserRepository.options);
      expect(cubit.state.conversationId, 'generated-id');
      expect(cubit.state.createdAt, isNotNull);
    });

    test('reuses the id and createdAt on subsequent saves / reopen', () async {
      final createdAt = DateTime(2026, 9);
      conversations.store['c1'] = Conversation(
        id: 'c1',
        type: ConversationType.proDealCloser,
        createdAt: createdAt,
        messages: const [ProDealCloserMessage(text: 'Old text')],
      );
      await cubit.start(conversationId: 'c1', vibe: 'friendly', locale: 'en');
      await cubit.sendText('New line');

      expect(await cubit.save(), isTrue);

      expect(conversations.store.keys, ['c1']);
      final saved = conversations.store['c1']!;
      expect(saved.createdAt, createdAt);
      expect(saved.title, 'Old text');
      expect(saved.messages.map((m) => m.text), contains('New line'));
    });

    test('uses "Untitled chat deal" for attachment-only chats', () async {
      cubit = build(idGenerator: () => 'id');
      await startFresh();
      await cubit.sendAttachments(['/a.png']);

      await cubit.save();

      expect(conversations.store['id']!.title, ProConversationTitle.untitled);
    });

    test('returns false when the store fails', () async {
      await startFresh();
      await cubit.sendText('Hello');
      conversations.failure = const CacheFailure('disk');

      expect(await cubit.save(), isFalse);
    });
  });

  test('a newer message supersedes a pending reply', () async {
    await startFresh();
    final slow = _SlowRepository();
    cubit = ProDealCloserCubit(
      repository: slow,
      conversationRepository: conversations,
      logger: testLogger(),
      uploadDelay: Duration.zero,
    );
    await cubit.start(vibe: 'friendly', locale: 'en');

    final first = cubit.sendText('first');
    final second = cubit.sendText('second');
    slow.complete();
    await Future.wait([first, second]);

    // Two user bubbles, exactly one wizard reply (for the latest request).
    final wizardReplies = cubit.state.messages.where((m) => m.isWizard && m.showActions);
    expect(wizardReplies, hasLength(1));
    expect(cubit.state.messages.where((m) => m.isUser), hasLength(2));
    expect(cubit.state.isTyping, isFalse);
  });
}

/// Repository whose replies resolve only when [complete] is called.
class _SlowRepository extends FakeProDealCloserRepository {
  final List<Completer<void>> _pending = [];

  void complete() {
    for (final c in _pending) {
      c.complete();
    }
    _pending.clear();
  }

  @override
  Future<Either<Failure, WizardReply>> getReply({
    required List<ProDealCloserMessage> history,
    required String vibe,
    required String locale,
    bool regenerate = false,
  }) async {
    final c = Completer<void>();
    _pending.add(c);
    await c.future;
    return super.getReply(history: history, vibe: vibe, locale: locale, regenerate: regenerate);
  }
}
