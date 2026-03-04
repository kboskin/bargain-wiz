import 'package:dartz/dartz.dart';
import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';

/// Single repository for all conversation types; API returns them all.
abstract class ConversationRepository {
  Future<Either<Failure, List<Conversation>>> getConversations();
  Future<Either<Failure, void>> saveConversation(Conversation conversation);
  Future<Either<Failure, void>> deleteConversation(String id);
  Future<Either<Failure, void>> clearAll();
}
