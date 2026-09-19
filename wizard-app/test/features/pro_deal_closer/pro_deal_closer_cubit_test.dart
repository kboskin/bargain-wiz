import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/pro_deal_closer/presentation/cubit/pro_deal_closer_cubit.dart';
import 'package:appwizard/features/pro_deal_closer/presentation/cubit/pro_deal_closer_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late FakeProDealCloserRepository repo;
  late FakeConversationRepository conversations;
  late ProDealCloserCubit cubit;

  setUp(() {
    repo = FakeProDealCloserRepository();
    conversations = FakeConversationRepository();
    cubit = ProDealCloserCubit(
      repository: repo,
      conversationRepository: conversations,
      logger: testLogger(),
    );
  });

  tearDown(() => cubit.close());

  Future<void> startFresh({String vibe = 'friendly'}) => cubit.start(vibe: vibe, locale: 'en');

  List<ProChatMessage> messages() => cubit.state.messages;

  group('start', () {
    test('fresh chat shows only the pinned greeting', () async {
      await startFresh();

      expect(cubit.state.status, ProDealCloserStatus.ready);
      expect(messages(), hasLength(1));
      expect(messages().single.isWizard, isTrue);
      expect(messages().single.text, ProDealCloserCubit.greetingText);
      expect(messages().single.showActions, isFalse);
      expect(cubit.state.hasUserMessages, isFalse);
      expect(cubit.state.conversationId, isNull);
      expect(cubit.state.vibe, 'friendly');
    });

    test('reopening a saved chat projects the server messages() as restored', () async {
      final createdAt = DateTime(2026, 9);
      conversations.store['c1'] = Conversation(
        id: 'c1',
        type: ConversationType.proDealCloser,
        createdAt: createdAt,
        status: ConversationStatus.won,
        vibe: 'tactical',
      );
      repo.store['c1'] = const [
        ProDealCloserMessage(id: 'm1', text: 'They ask 180', seq: 1),
        ProDealCloserMessage(
          id: 'm2',
          text: 'Reply',
          isWizard: true,
          seq: 2,
          options: FakeProDealCloserRepository.options,
        ),
      ];

      await cubit.start(conversationId: 'c1', vibe: 'friendly', locale: 'es');
      await pumpEventQueue();

      expect(cubit.state.conversationId, 'c1');
      expect(cubit.state.createdAt, createdAt);
      expect(cubit.state.conversationStatus, ConversationStatus.won);
      expect(cubit.state.locale, 'es');
      expect(messages().map((m) => m.text), [ProDealCloserCubit.greetingText, 'They ask 180', 'Reply']);
      expect(messages().every((m) => m.restored), isTrue);
      expect(messages().last.options, FakeProDealCloserRepository.options);
      expect(messages().last.showActions, isFalse);
      expect(cubit.state.isTyping, isFalse);
    });
  });

  group('sendText', () {
    test('shows the bubble at once, creates the conversation and renders the reply', () async {
      await startFresh(vibe: 'no_nonsense');

      final sending = cubit.sendText('  They ask 180  ');
      expect(messages().last.text, 'They ask 180');
      expect(messages().last.isUser, isTrue);
      expect(cubit.state.isTyping, isTrue);

      await sending;
      await pumpEventQueue();

      expect(repo.sendCalls.single.conversationId, isNull);
      expect(repo.sendCalls.single.text, 'They ask 180');
      expect(repo.sendCalls.single.vibe, 'no_nonsense');
      expect(cubit.state.conversationId, 'c1');
      expect(messages().map((m) => m.text), [ProDealCloserCubit.greetingText, 'They ask 180', 'Reply for no_nonsense']);
      expect(messages().where((m) => m.id.startsWith('local_')), isEmpty); // echoed, optimistic copy dropped
      expect(messages().last.showActions, isTrue);
      expect(messages().last.restored, isFalse);
      expect(cubit.state.isTyping, isFalse);
      expect(cubit.state.hasUserMessages, isTrue);
    });

    test('follow-ups reuse the conversation id and ignore sends while the wizard types', () async {
      await startFresh();
      await cubit.sendText('first');
      await pumpEventQueue();

      repo.autoReply = false;
      await cubit.sendText('second');
      await pumpEventQueue();
      expect(repo.sendCalls.last.conversationId, 'c1');
      expect(cubit.state.isTyping, isTrue); // pending placeholder from the server

      await cubit.sendText('third while typing');
      expect(repo.sendCalls, hasLength(2));

      repo.completeReply('c1', text: 'Late reply');
      await pumpEventQueue();
      expect(cubit.state.isTyping, isFalse);
      expect(messages().last.text, 'Late reply');
      expect(messages().last.showActions, isTrue);
    });

    test('a failed send keeps the bubble, marks it failed and reports the error once', () async {
      await startFresh();
      repo.failure = const ServerFailure('offline');

      await cubit.sendText('hello');
      await pumpEventQueue();

      expect(cubit.state.errorCount, 1);
      expect(cubit.state.failure, const ServerFailure('offline'));
      expect(cubit.state.isTyping, isFalse);
      expect(cubit.state.conversationId, isNull);
      expect(messages().last.text, 'hello');
      expect(messages().last.isFailed, isTrue);
    });

    test('the pending placeholder is the typing bubble, not an empty message', () async {
      await startFresh();
      repo.autoReply = false;

      await cubit.sendText('hello');
      await pumpEventQueue();

      // greeting + the user turn only: the wizard placeholder is still empty.
      expect(messages().map((m) => m.text), [ProDealCloserCubit.greetingText, 'hello']);
      expect(messages().every((m) => m.text.isNotEmpty), isTrue);
      expect(cubit.state.isTyping, isTrue);

      repo.completeReply('c1', text: 'Open at \$140.');
      await pumpEventQueue();

      expect(messages().last.text, 'Open at \$140.');
      expect(cubit.state.isTyping, isFalse);
    });

    test('a failed wizard reply renders its error text with actions (Redo)', () async {
      await startFresh();
      repo.autoReply = false;
      await cubit.sendText('hello');
      await pumpEventQueue();

      repo.completeReply('c1', failed: true);
      await pumpEventQueue();

      expect(cubit.state.isTyping, isFalse);
      expect(messages().last.isWizard, isTrue);
      expect(messages().last.text, 'The wizard fizzled');
      expect(messages().last.showActions, isTrue);
    });

    test('ignores empty text', () async {
      await startFresh();
      await cubit.sendText('   ');
      expect(repo.sendCalls, isEmpty);
      expect(messages(), hasLength(1));
    });
  });

  group('sendAttachments', () {
    test('keeps the local files for the bubble before and after the server echo', () async {
      await startFresh();

      final sending = cubit.sendAttachments(['/tmp/a.jpg', '/tmp/b.jpg']);
      expect(messages().last.attachmentPaths, ['/tmp/a.jpg', '/tmp/b.jpg']);
      expect(messages().last.isUploading, isTrue);
      expect(cubit.state.isTyping, isTrue);

      await sending;
      await pumpEventQueue();

      expect(repo.sendCalls.single.attachmentPaths, ['/tmp/a.jpg', '/tmp/b.jpg']);
      expect(repo.sendCalls.single.text, isNull);
      final user = messages()[1];
      expect(user.isUploading, isFalse);
      expect(user.attachmentPaths, ['/tmp/a.jpg', '/tmp/b.jpg']); // local paths win over stored refs
      expect(messages().last.text, 'Reply for friendly');
    });
  });

  group('options and redo', () {
    test('requestOptions attaches the lines and hides the action row', () async {
      await startFresh();
      await cubit.sendText('hello');
      await pumpEventQueue();
      final reply = messages().last;

      final requesting = cubit.requestOptions(reply.id);
      expect(messages().last.optionsLoading, isTrue);
      await requesting;
      await pumpEventQueue();

      expect(repo.optionsCalls, [reply.id]);
      expect(messages().last.options, FakeProDealCloserRepository.options);
      expect(messages().last.optionsLoading, isFalse);
      expect(messages().last.showActions, isFalse);
    });

    test('redo hides the old reply while the wizard works, then replaces it', () async {
      await startFresh();
      await cubit.sendText('hello');
      await pumpEventQueue();
      final reply = messages().last;

      repo.store['c1'] = [
        for (final m in repo.store['c1']!)
          if (m.id == reply.id) m.copyWith(status: MessageStatus.pending) else m,
      ];
      repo.emitFor('c1');
      await pumpEventQueue();

      expect(messages().map((m) => m.text), [ProDealCloserCubit.greetingText, 'hello']);
      expect(cubit.state.isTyping, isTrue);
    });

    test('redo replaces the reply text in place', () async {
      await startFresh(vibe: 'tactical');
      await cubit.sendText('hello');
      await pumpEventQueue();
      final reply = messages().last;

      cubit.setVibe('quiet_closer');
      await cubit.redo(reply.id);
      await pumpEventQueue();

      expect(repo.redoCalls, [reply.id]);
      expect(messages().last.id, reply.id);
      expect(messages().last.text, 'Reply for quiet_closer (Regenerated)');
      expect(messages(), hasLength(3));
    });

    test('failures surface through errorCount without touching the messages()', () async {
      await startFresh();
      await cubit.sendText('hello');
      await pumpEventQueue();
      final before = messages();
      repo.failure = const ServerFailure('boom');

      await cubit.requestOptions(messages().last.id);
      await cubit.redo(messages().last.id);

      expect(cubit.state.errorCount, 2);
      expect(messages().map((m) => m.text), before.map((m) => m.text));
    });
  });

  group('save', () {
    test('patches history metadata once the conversation exists on the server', () async {
      await startFresh(vibe: 'tactical');
      expect(await cubit.save(marketplace: 'ebay'), isFalse);

      await cubit.sendText('hello');
      await pumpEventQueue();

      expect(await cubit.save(marketplace: 'ebay'), isTrue);
      final saved = conversations.store['c1']!;
      expect(saved.type, ConversationType.proDealCloser);
      expect(saved.vibe, 'tactical');
      expect(saved.marketplace, 'ebay');
      expect(saved.status, ConversationStatus.open);
    });
  });
}
