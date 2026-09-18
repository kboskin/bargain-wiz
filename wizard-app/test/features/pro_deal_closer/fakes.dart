import 'dart:async';

import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:appwizard/features/pro_deal_closer/domain/entities/chat_send_result.dart';
import 'package:appwizard/features/pro_deal_closer/domain/repositories/pro_deal_closer_repository.dart';
import 'package:dartz/dartz.dart';

/// Recorded `send` call.
class SendCall {
  const SendCall({
    required this.conversationId,
    required this.requestId,
    required this.text,
    required this.attachmentPaths,
    required this.vibe,
  });

  final String? conversationId;
  final String requestId;
  final String? text;
  final List<String> attachmentPaths;
  final String vibe;
}

/// In-memory stand-in for the backend + listener: `send` stores the user turn and a wizard
/// reply ("Reply for {vibe}", or a pending placeholder when [autoReply] is false), options
/// are three fixed lines, redo appends " (Regenerated)". Set [failure] to make calls fail.
class FakeProDealCloserRepository implements ProDealCloserRepository {
  final Map<String, List<ProDealCloserMessage>> store = {};
  final Map<String, StreamController<List<ProDealCloserMessage>>> _controllers = {};
  final List<SendCall> sendCalls = [];
  final List<String> optionsCalls = [];
  final List<String> redoCalls = [];
  Failure? failure;
  bool autoReply = true;
  int _ids = 0;

  static const List<DealLine> options = [
    DealLine(text: 'Opener line', intent: DealIntent.opener, why: 'why 1'),
    DealLine(text: 'Counter line', intent: DealIntent.counter, why: 'why 2'),
    DealLine(text: 'Close line', intent: DealIntent.close, why: 'why 3'),
  ];

  @override
  Stream<List<ProDealCloserMessage>> watchMessages(String conversationId) async* {
    yield List.of(store[conversationId] ?? const []);
    yield* _controller(conversationId).stream;
  }

  @override
  Future<Either<Failure, ChatSendResult>> send({
    String? conversationId,
    required String requestId,
    String? text,
    List<String> attachmentPaths = const [],
    required String vibe,
    required String locale,
  }) async {
    sendCalls.add(SendCall(
      conversationId: conversationId,
      requestId: requestId,
      text: text,
      attachmentPaths: attachmentPaths,
      vibe: vibe,
    ));
    final f = failure;
    if (f != null) return Left(f);
    final cid = conversationId ?? 'c${++_ids}';
    final list = store.putIfAbsent(cid, () => []);
    final userId = 'm${++_ids}';
    final replyId = 'm${++_ids}';
    list
      ..add(ProDealCloserMessage(
        id: userId,
        text: text ?? '',
        attachments: [for (final p in attachmentPaths) ChatAttachment(storagePath: 'stored/$p')],
        requestId: requestId,
        seq: list.length + 1,
      ))
      ..add(ProDealCloserMessage(
        id: replyId,
        text: autoReply ? 'Reply for $vibe' : '',
        isWizard: true,
        status: autoReply ? MessageStatus.done : MessageStatus.pending,
        requestId: requestId,
        seq: list.length + 2,
      ));
    _emit(cid);
    return Right(ChatSendResult(conversationId: cid, messageId: userId, replyId: replyId));
  }

  /// Finishes a pending wizard reply (used with `autoReply = false`).
  void completeReply(String conversationId, {String text = 'Late reply', bool failed = false}) {
    _update(conversationId, (m) => m.isWizard && m.isPending
        ? m.copyWith(text: failed ? '' : text, status: failed ? MessageStatus.failed : MessageStatus.done,
            errorMessage: failed ? 'The wizard fizzled' : null)
        : m);
  }

  @override
  Future<Either<Failure, List<DealLine>>> requestOptions({
    required String conversationId,
    required String messageId,
    required String requestId,
    required String vibe,
    required String locale,
  }) async {
    optionsCalls.add(messageId);
    final f = failure;
    if (f != null) return Left(f);
    _update(conversationId, (m) => m.id == messageId ? m.copyWith(options: options) : m);
    return const Right(options);
  }

  @override
  Future<Either<Failure, void>> redo({
    required String conversationId,
    required String messageId,
    required String requestId,
    required String vibe,
    required String locale,
  }) async {
    redoCalls.add(messageId);
    final f = failure;
    if (f != null) return Left(f);
    _update(
      conversationId,
      (m) => m.id == messageId
          ? m.copyWith(text: 'Reply for $vibe (Regenerated)', revision: m.revision + 1, options: const [])
          : m,
    );
    return const Right(null);
  }

  void _update(String conversationId, ProDealCloserMessage Function(ProDealCloserMessage) change) {
    final list = store[conversationId];
    if (list == null) return;
    for (var i = 0; i < list.length; i++) {
      list[i] = change(list[i]);
    }
    _emit(conversationId);
  }

  StreamController<List<ProDealCloserMessage>> _controller(String conversationId) =>
      _controllers.putIfAbsent(conversationId, StreamController.broadcast);

  void _emit(String conversationId) {
    final controller = _controllers[conversationId];
    if (controller != null && controller.hasListener) controller.add(List.of(store[conversationId]!));
  }
}

/// In-memory conversation store (history metadata).
class FakeConversationRepository implements ConversationRepository {
  final Map<String, Conversation> store = {};
  Failure? failure;

  @override
  Future<Either<Failure, List<Conversation>>> getConversations() async {
    final f = failure;
    if (f != null) return Left(f);
    return Right(store.values.toList());
  }

  @override
  Future<Either<Failure, void>> saveConversation(Conversation conversation) async {
    final f = failure;
    if (f != null) return Left(f);
    store[conversation.id] = conversation;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteConversation(String id) async {
    store.remove(id);
    return const Right(null);
  }

}

AppLogger testLogger() => AppLogger(null);
