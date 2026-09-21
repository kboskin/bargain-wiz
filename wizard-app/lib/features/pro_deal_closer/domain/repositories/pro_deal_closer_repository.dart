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
  /// reply arrives through [watchMessages]. The server refuses a second turn while one is in
  /// flight (409), so a turn needs no client key to tell it apart from another.
  Future<Either<Failure, ChatSendResult>> send({
    String? conversationId,
    String? text,
    List<String> attachmentPaths = const [],
    required Map<String, dynamic> overrides,
    required String locale,
  });

  /// Asks for three lines (opener / counter / close) on the wizard reply [messageId]. The
  /// backend queues the work; the lines arrive through [watchMessages], and the message
  /// carries `pendingOptions` while they are on the way.
  Future<Either<Failure, void>> requestOptions({
    required String conversationId,
    required String messageId,
    required Map<String, dynamic> overrides,
    required String locale,
  });

  /// Regenerates the wizard reply [messageId] in place ("Redo").
  Future<Either<Failure, void>> redo({
    required String conversationId,
    required String messageId,
    required Map<String, dynamic> overrides,
    required String locale,
  });
}
