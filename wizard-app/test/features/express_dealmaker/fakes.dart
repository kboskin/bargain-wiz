import 'dart:async';

import 'package:dartz/dartz.dart';

import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:appwizard/features/express_dealmaker/domain/entities/deal_reply.dart';
import 'package:appwizard/features/express_dealmaker/domain/entities/upload_screenshot_result.dart';
import 'package:appwizard/features/express_dealmaker/domain/repositories/express_dealmaker_repository.dart';

/// One recorded `getDealReply` call.
class ReplyRequest {
  const ReplyRequest({required this.ids, required this.locale, this.keyword, this.vibe});
  final List<String> ids;
  final String locale;
  final String? keyword;
  final String? vibe;
}

/// In-memory Express repository: uploads succeed unless the path is in
/// [failingPaths]; replies fail while [failReply] is true.
class FakeExpressRepository implements ExpressDealmakerRepository {
  final Set<String> failingPaths = {};
  bool failReply = false;
  final List<String> uploadedPaths = [];
  final List<ReplyRequest> replyRequests = [];
  /// Conversation id the last reply was asked for: null = "create a new deal", set = redo.
  String? lastConversationId;
  /// When set, uploads wait for this completer before finishing.
  Completer<void>? uploadGate;

  DealReply reply = const DealReply(
    seeing: r'IKEA Kallax shelf · $180 · listed 9 days · "slight scuff"',
    lines: [
      DealLine(text: 'Hi! Is the Kallax still available?', intent: DealIntent.opener, why: 'Warm open.'),
      DealLine(text: r'Could you do $160 tonight?', intent: DealIntent.counter, why: 'Concedes a little.'),
      DealLine(text: r'$160 sounds good — what time?', intent: DealIntent.close, why: 'Assumes the yes.'),
    ],
  );

  @override
  Future<Either<Failure, UploadScreenshotResult>> uploadScreenshot(final String filePath) async {
    uploadedPaths.add(filePath);
    final gate = uploadGate;
    if (gate != null) await gate.future;
    if (failingPaths.contains(filePath)) return const Left(ServerFailure('upload failed'));
    return Right(UploadScreenshotResult(id: 'id_$filePath'));
  }

  @override
  Future<Either<Failure, DealReply>> getDealReply({
    required final List<String> uploadedIds,
    required final String locale,
    final String? keyword,
    final String? vibe,
    final String? conversationId,
  }) async {
    replyRequests.add(ReplyRequest(ids: uploadedIds, locale: locale, keyword: keyword, vibe: vibe));
    lastConversationId = conversationId;
    if (failReply) return const Left(ServerFailure('reply failed'));
    // Like the backend: the first reply creates the conversation, later ones keep its id.
    return Right(DealReply(lines: reply.lines, seeing: reply.seeing, conversationId: conversationId ?? 'conv_1'));
  }
}

/// In-memory conversation store.
class FakeConversationRepository implements ConversationRepository {
  final Map<String, Conversation> store = {};

  @override
  Future<Either<Failure, List<Conversation>>> getConversations() async => Right(store.values.toList());

  @override
  Future<Either<Failure, void>> saveConversation(final Conversation conversation) async {
    store[conversation.id] = conversation;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteConversation(final String id) async {
    store.remove(id);
    return const Right(null);
  }

}
