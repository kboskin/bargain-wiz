import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/pro_deal_closer/domain/entities/chat_send_result.dart';
import 'package:dartz/dartz.dart';

/// Pro Deal Closer over backend-owned conversations (CONVERSATIONS.md): writes go to the
/// `conversations` function, the chat itself is read with [watchMessages].
abstract class ProDealCloserRepository {
  /// Live messages of [conversationId] in server order; a wizard message with
  /// [MessageStatus.pending] is the typing indicator.
  Stream<List<ProDealCloserMessage>> watchMessages(String conversationId);

  /// Sends one user turn. Without [conversationId] a new conversation is created. The wizard
  /// reply arrives through [watchMessages]; [requestId] makes retries idempotent.
  Future<Either<Failure, ChatSendResult>> send({
    String? conversationId,
    required String requestId,
    String? text,
    List<String> attachmentPaths = const [],
    required String vibe,
    required String locale,
  });

  /// Three lines (opener / counter / close) for the wizard reply [messageId].
  Future<Either<Failure, List<DealLine>>> requestOptions({
    required String conversationId,
    required String messageId,
    required String requestId,
    required String vibe,
    required String locale,
  });

  /// Regenerates the wizard reply [messageId] in place ("Redo").
  Future<Either<Failure, void>> redo({
    required String conversationId,
    required String messageId,
    required String requestId,
    required String vibe,
    required String locale,
  });
}
