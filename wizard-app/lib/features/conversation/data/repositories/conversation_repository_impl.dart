import 'package:dartz/dartz.dart';

import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/conversation/data/datasources/conversation_local_datasource.dart';
import 'package:appwizard/features/conversation/data/mappers/conversation_mapper.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/conversation/domain/repositories/conversation_repository.dart';

class ConversationRepositoryImpl implements ConversationRepository {
  ConversationRepositoryImpl(this._local, this._mapper, this._logger);

  final ConversationLocalDataSource _local;
  final ConversationMapper _mapper;
  final AppLogger _logger;

  @override
  Future<Either<Failure, List<Conversation>>> getConversations() async {
    try {
      final models = await _local.getConversations();
      final entities = models.map(_mapper.toEntity).toList();
      return Right(entities);
    } catch (e, stackTrace) {
      _logger.e('Error getting conversations', e, stackTrace);
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> saveConversation(Conversation conversation) async {
    try {
      final model = _mapper.toModel(conversation);
      await _local.saveConversation(model);
      return const Right(null);
    } catch (e, stackTrace) {
      _logger.e('Error saving conversation', e, stackTrace);
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteConversation(String id) async {
    try {
      await _local.deleteConversation(id);
      return const Right(null);
    } catch (e, stackTrace) {
      _logger.e('Error deleting conversation', e, stackTrace);
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> clearAll() async {
    try {
      await _local.clearAll();
      return const Right(null);
    } catch (e, stackTrace) {
      _logger.e('Error clearing conversations', e, stackTrace);
      return Left(CacheFailure(e.toString()));
    }
  }
}
