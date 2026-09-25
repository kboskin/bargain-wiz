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

  Future<void> startFresh({String vibe = 'friendly', String marketplace = 'ebay'}) =>
      cubit.start(overrides: {'vibe': vibe, 'marketplace': marketplace}, locale: 'en');

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
      expect(cubit.state.overrides, {'vibe': 'friendly', 'marketplace': 'ebay'});
    });

    test('reopening a saved chat projects the server messages() as restored', () async {
      final createdAt = DateTime(2026, 9);
      conversations.store['c1'] = Conversation(
        id: 'c1',
        type: ConversationType.proDealCloser,
        createdAt: createdAt,
        status: ConversationStatus.won,
        overrides: const {'vibe': 'tactical'},
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

      await cubit.start(conversationId: 'c1', overrides: const {'vibe': 'friendly'}, locale: 'es');
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
      // The deal keeps the answers it was written with, not the profile defaults passed in:
      // the transcript above was coached in that voice (CONVERSATIONS.md).
      expect(cubit.state.overrides, {'vibe': 'tactical'});
    });

    test('a reopened deal with no saved answers falls back to the profile defaults', () async {
      conversations.store['c2'] = Conversation(
        id: 'c2',
        type: ConversationType.proDealCloser,
        createdAt: DateTime(2026, 9),
      );
      repo.store['c2'] = const [ProDealCloserMessage(id: 'm1', text: 'hi', seq: 1)];

      await cubit.start(conversationId: 'c2', overrides: const {'vibe': 'friendly'}, locale: 'en');
      await pumpEventQueue();

      expect(cubit.state.overrides, {'vibe': 'friendly'});
    });

    test('every request carries the answers the deal started with', () async {
      // The chat has no route to the stored profile at all: what the deal starts from is the
      // Profile screen's to change, and nothing in here moves it.
      await startFresh(vibe: 'friendly');

      await cubit.send(text: 'hello');
      await pumpEventQueue();

      expect(repo.sendCalls.single.overrides['vibe'], 'friendly');
    });
  });

  group('objective', () {
    const discount = 'Objective: get a discount.';
    const followUp = 'Objective: follow up.';

    test('is picked before the chat starts, cleared by tapping it again, and sent with the turn',
        () async {
      await startFresh();
      expect(cubit.state.canPickObjective, isTrue);

      cubit
        ..selectObjective(followUp)
        ..selectObjective(followUp);
      expect(cubit.state.objective, isNull);
      cubit.selectObjective(discount);
      expect(cubit.state.objective, discount);

      await cubit.send(text: 'They ask 180');
      await pumpEventQueue();

      expect(repo.sendCalls.single.objective, discount);
      // The conversation now keeps it: it cannot change for the rest of the chat.
      expect(cubit.state.canPickObjective, isFalse);
      cubit.selectObjective(followUp);
      expect(cubit.state.objective, discount);
    });

    test('stays open to change after a first send that failed', () async {
      await startFresh();
      cubit.selectObjective(discount);
      repo.failure = const ServerFailure('offline');

      await cubit.send(text: 'hello');
      await pumpEventQueue();

      expect(cubit.state.conversationId, isNull);
      expect(cubit.state.canPickObjective, isTrue);
      cubit.selectObjective(followUp);
      expect(cubit.state.objective, followUp);
    });

    test('a reopened chat shows the objective it was started for, locked', () async {
      conversations.store['c1'] = Conversation(
        id: 'c1',
        type: ConversationType.proDealCloser,
        createdAt: DateTime(2026, 9),
        objective: followUp,
      );
      repo.store['c1'] = const [ProDealCloserMessage(id: 'm1', text: 'hi', seq: 1)];

      await cubit.start(conversationId: 'c1', overrides: const {}, locale: 'en');
      await pumpEventQueue();

      expect(cubit.state.objective, followUp);
      expect(cubit.state.canPickObjective, isFalse);
    });
  });

  group('send: text', () {
    test('shows the bubble at once, creates the conversation and renders the reply', () async {
      await startFresh(vibe: 'no_nonsense');

      final sending = cubit.send(text: '  They ask 180  ');
      expect(messages().last.text, 'They ask 180');
      expect(messages().last.isUser, isTrue);
      expect(cubit.state.isTyping, isTrue);

      await sending;
      await pumpEventQueue();

      expect(repo.sendCalls.single.conversationId, isNull);
      expect(repo.sendCalls.single.text, 'They ask 180');
      expect(repo.sendCalls.single.overrides['vibe'], 'no_nonsense');
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
      await cubit.send(text: 'first');
      await pumpEventQueue();

      repo.autoReply = false;
      await cubit.send(text: 'second');
      await pumpEventQueue();
      expect(repo.sendCalls.last.conversationId, 'c1');
      expect(cubit.state.isTyping, isTrue); // pending placeholder from the server

      await cubit.send(text: 'third while typing');
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

      await cubit.send(text: 'hello');
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

      await cubit.send(text: 'hello');
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
      await cubit.send(text: 'hello');
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
      await cubit.send(text: '   ');
      expect(repo.sendCalls, isEmpty);
      expect(messages(), hasLength(1));
    });
  });

  group('send: screenshots', () {
    test('keeps the local files for the bubble before and after the server echo', () async {
      await startFresh();

      final sending = cubit.send(paths: ['/tmp/a.jpg', '/tmp/b.jpg']);
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

    test('screenshots and text picked together go out as one turn, one bubble', () async {
      await startFresh();

      final sending = cubit.send(text: '  My budget is 70  ', paths: ['/tmp/a.jpg']);
      final pending = messages().last;
      expect(pending.text, 'My budget is 70');
      expect(pending.attachmentPaths, ['/tmp/a.jpg']);
      expect(pending.isUploading, isTrue);

      await sending;
      await pumpEventQueue();

      final call = repo.sendCalls.single;
      expect(call.text, 'My budget is 70');
      expect(call.attachmentPaths, ['/tmp/a.jpg']);
      final user = messages()[1];
      expect(user.text, 'My budget is 70');
      expect(user.attachmentPaths, ['/tmp/a.jpg']);
      expect(messages().where((final m) => m.isUser), hasLength(1));
      expect(messages().last.text, 'Reply for friendly');
    });
  });

  group('options and redo', () {
    test('requestOptions attaches the lines and hides the action row', () async {
      await startFresh();
      await cubit.send(text: 'hello');
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
      await cubit.send(text: 'hello');
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
      await startFresh(vibe: 'quiet_closer');
      await cubit.send(text: 'hello');
      await pumpEventQueue();
      final reply = messages().last;

      await cubit.redo(reply.id);
      await pumpEventQueue();

      expect(repo.redoCalls, [reply.id]);
      expect(messages().last.id, reply.id);
      expect(messages().last.text, 'Reply for quiet_closer (Regenerated)');
      expect(messages(), hasLength(3));
    });

    test('failures surface through errorCount without touching the messages()', () async {
      await startFresh();
      await cubit.send(text: 'hello');
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
      expect(await cubit.save(), isFalse);

      await cubit.send(text: 'hello');
      await pumpEventQueue();

      expect(await cubit.save(), isTrue);
      final saved = conversations.store['c1']!;
      expect(saved.type, ConversationType.proDealCloser);
      expect(saved.overrides, {'vibe': 'tactical', 'marketplace': 'ebay'});
      expect(saved.status, ConversationStatus.open);
    });
  });
}
