import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/conversation/data/mappers/conversation_type_mapper.dart';
import 'package:appwizard/features/conversation/data/models/conversation_model.dart';
import 'package:appwizard/features/conversation/data/models/pro_deal_closer_message_model.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';

/// Maps [ConversationModel] to/from [Conversation] entity.
/// Uses [ConversationTypeMapper] for type. Relies on model for deserialization; on exception returns empty lists and logs.
class ConversationMapper {
  ConversationMapper(this._typeMapper, this._logger);

  final ConversationTypeMapper _typeMapper;
  final AppLogger _logger;

  Conversation toEntity(ConversationModel model) {
    try {
      final messages = model.messages
          .map((m) => m.toEntity())
          .toList();
      return Conversation(
        id: model.id,
        type: _typeMapper.toEntity(model.type),
        screenshotPaths: List<String>.from(model.screenshotPaths),
        replyOptions: List<String>.from(model.replyOptions),
        keyword: model.keyword,
        messages: messages,
        createdAt: DateTime.fromMillisecondsSinceEpoch(model.createdAtMillis),
      );
    } on Object catch (e, stackTrace) {
      _logger.e('ConversationMapper.toEntity failed', e, stackTrace);
      return Conversation(
        id: model.id,
        type: _typeMapper.toEntity(model.type),
        screenshotPaths: const [],
        replyOptions: const [],
        keyword: model.keyword,
        messages: const [],
        createdAt: DateTime.fromMillisecondsSinceEpoch(model.createdAtMillis),
      );
    }
  }

  ConversationModel toModel(Conversation entity) {
    try {
      final messages = entity.messages
          .map((m) => ProDealCloserMessageModel.fromEntity(m))
          .toList();
      return ConversationModel(
        id: entity.id,
        type: _typeMapper.toModel(entity.type),
        screenshotPaths: List<String>.from(entity.screenshotPaths),
        replyOptions: List<String>.from(entity.replyOptions),
        keyword: entity.keyword,
        messages: messages,
        createdAtMillis: entity.createdAt.millisecondsSinceEpoch,
      );
    } on Object catch (e, stackTrace) {
      _logger.e('ConversationMapper.toModel failed', e, stackTrace);
      return ConversationModel(
        id: entity.id,
        type: _typeMapper.toModel(entity.type),
        screenshotPaths: const [],
        replyOptions: const [],
        keyword: entity.keyword,
        messages: const [],
        createdAtMillis: entity.createdAt.millisecondsSinceEpoch,
      );
    }
  }
}
