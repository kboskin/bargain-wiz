import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:appwizard/core/config/prefs_keys.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/express_dealmaker/presentation/cubit/express_dealmaker_cubit.dart';
import 'package:appwizard/features/express_dealmaker/presentation/pages/screenshot_upload_item.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeExpressRepository repo;
  late FakeConversationRepository conversations;
  late SharedPreferences prefs;
  late ExpressDealmakerCubit cubit;

  ExpressDealmakerCubit build({final String vibeId = 'friendly', final String? marketplace = 'facebook'}) =>
      ExpressDealmakerCubit(
        repository: repo,
        conversationRepository: conversations,
        prefs: prefs,
        vibeId: vibeId,
        marketplace: marketplace,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = FakeExpressRepository();
    conversations = FakeConversationRepository();
    cubit = build();
  });

  tearDown(() => cubit.close());

  group('pick → uploading → ready', () {
    test('starts in pick with no args and collects picked paths', () async {
      await cubit.start();
      expect(cubit.state.phase, ExpressPhase.pick);
      expect(cubit.state.hasScreenshots, isFalse);

      cubit.addPaths(['a.png', 'b.png', 'a.png']);
      expect(cubit.state.paths, ['a.png', 'b.png']); // duplicates ignored
      expect(cubit.state.screenshots.every((final s) => s.isUploading), isTrue);
      expect(repo.uploadedPaths, isEmpty); // nothing uploaded while picking

      cubit.removeAt(1);
      expect(cubit.state.paths, ['a.png']);
    });

    test('startUpload uploads everything, then auto-requests the reply', () async {
      final phases = <ExpressPhase>[];
      final sub = cubit.stream.listen((final s) => phases.add(s.phase));

      await cubit.start();
      cubit.addPaths(['a.png', 'b.png']);
      await cubit.startUpload();
      await pumpEventQueue(); // broadcast stream delivers in a later microtask

      expect(phases, containsAllInOrder([ExpressPhase.uploading, ExpressPhase.ready]));
      expect(cubit.state.phase, ExpressPhase.ready);
      expect(cubit.state.replyLoading, isFalse);
      expect(cubit.state.uploadedIds, ['id_a.png', 'id_b.png']);
      expect(cubit.state.lines, repo.reply.lines);
      expect(cubit.state.seeing, repo.reply.seeing);
      expect(cubit.state.requestId, 1);
      expect(repo.replyRequests, hasLength(1));
      expect(repo.replyRequests.single.ids, ['id_a.png', 'id_b.png']);
      expect(repo.replyRequests.single.vibe, 'friendly');
      expect(repo.replyRequests.single.locale, 'en');
      expect(repo.replyRequests.single.keyword, isNull);
      expect(prefs.getBool(PrefsKeys.expressUsed), isTrue);
      await sub.cancel();
    });

    test('start with initialPaths skips the pick stage', () async {
      final phases = <ExpressPhase>[];
      final sub = cubit.stream.listen((final s) => phases.add(s.phase));

      await cubit.start(initialPaths: ['x.png']);
      await pumpEventQueue();

      expect(phases.first, ExpressPhase.uploading);
      expect(phases, isNot(contains(ExpressPhase.pick)));
      expect(cubit.state.phase, ExpressPhase.ready);
      await sub.cancel();
    });

    test('reply while uploading is flagged as loading until it returns', () async {
      repo.uploadGate = Completer<void>();
      await cubit.start();
      cubit.addPaths(['a.png']);
      final upload = cubit.startUpload();
      expect(cubit.state.phase, ExpressPhase.uploading);
      expect(cubit.state.anyUploading, isTrue);

      repo.uploadGate!.complete();
      await upload;
      expect(cubit.state.phase, ExpressPhase.ready);
    });
  });

  group('failures', () {
    test('all uploads failing → error(upload); retry after fix → ready', () async {
      repo.failingPaths.addAll(['a.png', 'b.png']);
      await cubit.start(initialPaths: ['a.png', 'b.png']);

      expect(cubit.state.phase, ExpressPhase.error);
      expect(cubit.state.errorKind, ExpressErrorKind.upload);
      expect(cubit.state.screenshots.every((final s) => s.isFailed), isTrue);
      expect(repo.replyRequests, isEmpty);

      repo.failingPaths.clear();
      await cubit.retry();

      expect(cubit.state.phase, ExpressPhase.ready);
      expect(cubit.state.uploadedIds, ['id_a.png', 'id_b.png']);
      expect(repo.uploadedPaths, ['a.png', 'b.png', 'a.png', 'b.png']);
    });

    test('reply failing → error(reply); retry does not re-upload', () async {
      repo.failReply = true;
      await cubit.start(initialPaths: ['a.png']);

      expect(cubit.state.phase, ExpressPhase.error);
      expect(cubit.state.errorKind, ExpressErrorKind.reply);
      expect(cubit.state.lines, isEmpty);

      repo.failReply = false;
      await cubit.retry();

      expect(cubit.state.phase, ExpressPhase.ready);
      expect(cubit.state.lines, isNotEmpty);
      expect(repo.uploadedPaths, ['a.png']);
      expect(repo.replyRequests, hasLength(2));
    });

    test('partial failure keeps the failed shot, proceeds with the rest; per-card retry fixes it', () async {
      repo.failingPaths.add('bad.png');
      await cubit.start(initialPaths: ['ok.png', 'bad.png']);

      expect(cubit.state.phase, ExpressPhase.ready);
      expect(cubit.state.screenshots[0].isSuccess, isTrue);
      expect(cubit.state.screenshots[1].isFailed, isTrue);
      expect(repo.replyRequests.single.ids, ['id_ok.png']);

      repo.failingPaths.clear();
      await cubit.retryUpload(1);

      expect(cubit.state.screenshots[1].status, ScreenshotUploadStatus.success);
      expect(cubit.state.phase, ExpressPhase.ready);
      expect(repo.replyRequests, hasLength(1)); // no automatic re-request in results

      await cubit.requestReply();
      expect(repo.replyRequests.last.ids, ['id_ok.png', 'id_bad.png']);
    });

    test('a failed first reply keeps the deal, so Retry regenerates it instead of opening a second',
        () async {
      repo.failReply = true;
      await cubit.start(initialPaths: ['a.png']);

      expect(cubit.state.phase, ExpressPhase.error);
      expect(cubit.state.conversationId, 'conv_1', reason: 'the backend created it before it failed');

      repo.failReply = false;
      await cubit.retry();

      expect(cubit.state.phase, ExpressPhase.ready);
      expect(cubit.state.conversationId, 'conv_1');
      expect(
        repo.replyRequests.map((final r) => r.conversationId),
        [null, 'conv_1'],
        reason: 'exactly one deal was created; the retry regenerated it',
      );
    });

    test('a reply that never reached the backend still opens a deal on Retry', () async {
      repo
        ..failReply = true
        ..failureKeepsConversation = false;
      await cubit.start(initialPaths: ['a.png']);

      expect(cubit.state.conversationId, isNull);

      repo.failReply = false;
      await cubit.retry();

      expect(repo.replyRequests.map((final r) => r.conversationId), [null, null]);
      expect(cubit.state.phase, ExpressPhase.ready);
    });

    test('nothing to retry with no screenshots falls back to pick', () async {
      await cubit.retry();
      expect(cubit.state.phase, ExpressPhase.pick);
    });
  });

  group('results interactions', () {
    setUp(() async {
      await cubit.start(initialPaths: ['a.png']);
    });

    test('Get More re-requests with keyword and tone, bumping requestId', () async {
      cubit.setKeyword('  pickup today ');
      await cubit.requestReply();

      expect(repo.replyRequests, hasLength(2));
      expect(repo.replyRequests.last.keyword, 'pickup today');
      expect(repo.replyRequests.last.vibe, 'friendly');
      expect(cubit.state.requestId, 2);
      expect(cubit.state.phase, ExpressPhase.ready);
    });

    test('changing the tone re-requests with the new vibe', () async {
      await cubit.changeVibe('tactical');
      expect(cubit.state.vibeId, 'tactical');
      expect(repo.replyRequests.last.vibe, 'tactical');

      await cubit.changeVibe('tactical'); // same tone → no request
      expect(repo.replyRequests, hasLength(2));
    });

    test('adding screenshots from results uploads them and re-requests', () async {
      cubit.addPaths(['b.png']);
      expect(cubit.state.phase, ExpressPhase.uploading);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.phase, ExpressPhase.ready);
      expect(repo.uploadedPaths, ['a.png', 'b.png']);
      expect(repo.replyRequests.last.ids, ['id_a.png', 'id_b.png']);
    });

    test('a failing Get More shows the error stage and Retry re-requests', () async {
      repo.failReply = true;
      await cubit.requestReply();
      expect(cubit.state.phase, ExpressPhase.error);
      expect(cubit.state.lines, isNotEmpty); // previous lines are kept

      repo.failReply = false;
      await cubit.retry();
      expect(cubit.state.phase, ExpressPhase.ready);
    });
  });

  group('persistence', () {
    test('nothing is saved before results exist', () async {
      await cubit.start();
      cubit.addPaths(['a.png']);
      expect(await cubit.saveConversation(), isFalse);
      expect(conversations.store, isEmpty);
    });

    test('saveConversation writes an express conversation with a derived title', () async {
      await cubit.start(initialPaths: ['a.png', 'b.png']);
      cubit.setKeyword('cash');
      await cubit.changeVibe('quiet_closer');

      expect(await cubit.saveConversation(), isTrue);
      final saved = conversations.store.values.single;
      expect(saved.type, ConversationType.express);
      expect(saved.title, 'IKEA Kallax shelf');
      expect(saved.screenshotPaths, ['a.png', 'b.png']);
      expect(saved.replyLines, repo.reply.lines);
      expect(saved.effectiveLines, repo.reply.lines);
      expect(saved.keyword, 'cash');
      expect(saved.seeing, repo.reply.seeing);
      expect(saved.vibe, 'quiet_closer');
      expect(saved.marketplace, 'facebook');
      expect(saved.status, ConversationStatus.open);
    });

    test('reopening jumps to results with saved data and keeps the id on save', () async {
      final createdAt = DateTime(2026, 9, 3);
      conversations.store['42'] = Conversation(
        id: '42',
        type: ConversationType.express,
        screenshotPaths: const ['old.png'],
        replyLines: const [DealLine(text: 'Saved line', intent: DealIntent.counter)],
        keyword: 'shelf',
        createdAt: createdAt,
        seeing: r'Old shelf · $90',
        vibe: 'no_nonsense',
        status: ConversationStatus.won,
      );

      final phases = <ExpressPhase>[];
      final sub = cubit.stream.listen((final s) => phases.add(s.phase));
      await cubit.start(conversationId: '42');
      await pumpEventQueue();

      expect(phases, isNot(contains(ExpressPhase.uploading)));
      expect(phases.last, ExpressPhase.ready);
      expect(cubit.state.phase, ExpressPhase.ready);
      expect(cubit.state.conversationId, '42');
      expect(cubit.state.lines.single.text, 'Saved line');
      expect(cubit.state.seeing, r'Old shelf · $90');
      expect(cubit.state.keyword, 'shelf');
      expect(cubit.state.vibeId, 'no_nonsense');
      expect(cubit.state.screenshots.single.isSuccess, isTrue);
      expect(cubit.state.uploadedIds, ['old.png']); // path fallback for restored shots
      expect(repo.uploadedPaths, isEmpty);

      cubit.setKeyword('shelf discount');
      expect(await cubit.saveConversation(), isTrue);
      expect(conversations.store, hasLength(1));
      final saved = conversations.store['42']!;
      expect(saved.createdAt, createdAt);
      expect(saved.status, ConversationStatus.won);
      expect(saved.keyword, 'shelf discount');
      expect(saved.title, 'Old shelf');
      await sub.cancel();
    });

    test('unknown conversation id falls back to pick', () async {
      await cubit.start(conversationId: 'missing');
      expect(cubit.state.phase, ExpressPhase.pick);
      expect(cubit.state.loadingConversation, isFalse);
    });

    test('a deal whose generation failed reopens as an error, not a bare picker', () async {
      conversations.store['43'] = Conversation(
        id: '43',
        type: ConversationType.express,
        createdAt: DateTime(2026, 9, 18),
        errorMessage: 'The wizard could not answer. Try again.',
      );

      await cubit.start(conversationId: '43');

      expect(cubit.state.phase, ExpressPhase.error);
      expect(cubit.state.errorKind, ExpressErrorKind.reply);
      expect(cubit.state.errorMessage, 'The wizard could not answer. Try again.');
      expect(cubit.state.conversationId, '43');
    });

    test('retrying a failed deal regenerates it without re-picking screenshots', () async {
      conversations.store['44'] = Conversation(
        id: '44',
        type: ConversationType.express,
        createdAt: DateTime(2026, 9, 18),
        errorMessage: 'The wizard could not answer. Try again.',
      );
      await cubit.start(conversationId: '44');
      expect(cubit.state.uploadedIds, isEmpty); // a failed deal projects no screenshots

      await cubit.retry();

      // Reached the backend with the existing conversation, uploading nothing.
      expect(repo.uploadedPaths, isEmpty);
      expect(repo.lastConversationId, '44');
      expect(cubit.state.phase, ExpressPhase.ready);
    });

    test('a deal that never produced lines is not saved over the title the backend derived',
        () async {
      conversations.store['46'] = Conversation(
        id: '46',
        type: ConversationType.express,
        createdAt: DateTime(2026, 9, 18),
        title: 'Screenshot deal',
        errorMessage: 'The wizard could not answer. Try again.',
      );
      await cubit.start(conversationId: '46');

      expect(await cubit.saveConversation(), isFalse);
      expect(conversations.store['46']!.title, 'Screenshot deal');
    });

    test('screenshots added to an existing deal start a new one instead of being dropped',
        () async {
      conversations.store['45'] = Conversation(
        id: '45',
        type: ConversationType.express,
        createdAt: DateTime(2026, 9, 18),
        errorMessage: 'The wizard could not answer. Try again.',
      );
      await cubit.start(conversationId: '45');
      expect(cubit.state.conversationId, '45');

      cubit.addPaths(const ['fresh.png']);
      expect(cubit.state.conversationId, isNull, reason: 'express takes no follow-up turns');

      await cubit.startUpload();
      await pumpEventQueue();

      // The new screenshot was actually sent, and it opened its own deal.
      expect(repo.uploadedPaths, ['fresh.png']);
      expect(repo.lastConversationId, isNull);
      expect(cubit.state.phase, ExpressPhase.ready);
    });
  });
}
