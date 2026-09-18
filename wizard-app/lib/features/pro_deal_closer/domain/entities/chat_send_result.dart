import 'package:equatable/equatable.dart';

/// Ids the backend returns after a turn was accepted: subscribe with [conversationId], the
/// user turn is [messageId], the wizard placeholder (pending → done) is [replyId].
class ChatSendResult extends Equatable {
  const ChatSendResult({required this.conversationId, this.messageId, this.replyId});

  final String conversationId;
  final String? messageId;
  final String? replyId;

  @override
  List<Object?> get props => [conversationId, messageId, replyId];
}
