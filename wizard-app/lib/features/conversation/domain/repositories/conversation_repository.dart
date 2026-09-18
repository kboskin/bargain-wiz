import 'package:dartz/dartz.dart';
import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';

/// Single repository for all conversation types; API returns them all.
abstract class ConversationRepository {
  Future<Either<Failure, List<Conversation>>> getConversations();
  Future<Either<Failure, void>> saveConversation(Conversation conversation);
  /// Removes the deal from the user's history (the backend archives it, nothing is destroyed).
  Future<Either<Failure, void>> deleteConversation(String id);
}

/// Convenience queries built on the core CRUD above. Implemented as an extension
/// so every [ConversationRepository] (including test fakes) gets them for free.
extension ConversationRepositoryX on ConversationRepository {
  /// The stored conversation with [id], or `null` when it does not exist.
  Future<Either<Failure, Conversation?>> findById(String id) async {
    final result = await getConversations();
    return result.map((list) => list.where((c) => c.id == id).firstOrNull);
  }

  /// Sets [status] (and [priceAfter] when given) on conversation [id] and persists it.
  /// Returns the updated entity; a [CacheFailure] when the id is unknown.
  Future<Either<Failure, Conversation>> updateStatus(
    String id,
    ConversationStatus status, {
    String? priceAfter,
  }) async {
    final found = await findById(id);
    return found.fold<Future<Either<Failure, Conversation>>>(
      (failure) async => Left(failure),
      (conversation) async {
        if (conversation == null) {
          return Left(CacheFailure('Conversation $id not found'));
        }
        final updated = conversation.copyWith(status: status, priceAfter: priceAfter);
        final saved = await saveConversation(updated);
        return saved.map((_) => updated);
      },
    );
  }
}
