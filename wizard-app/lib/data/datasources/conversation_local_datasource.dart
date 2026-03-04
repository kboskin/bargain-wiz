import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/data/models/conversation_model.dart';

/// Single local datasource for all conversation types; API would return them all.
abstract class ConversationLocalDataSource {
  Future<List<ConversationModel>> getConversations();
  Future<void> saveConversation(ConversationModel conversation);
  Future<void> deleteConversation(String id);
  Future<void> clearAll();
}

class ConversationLocalDataSourceImpl implements ConversationLocalDataSource {
  ConversationLocalDataSourceImpl(this._prefs, this._logger);

  /// Keep key for backward compatibility with previously saved data.
  static const String _conversationsKey = 'express_conversations';

  final SharedPreferences _prefs;
  final AppLogger _logger;

  @override
  Future<List<ConversationModel>> getConversations() async {
    try {
      final jsonString = _prefs.getString(_conversationsKey);
      if (jsonString == null) return <ConversationModel>[];
      final decoded = jsonDecode(jsonString) as List<dynamic>;
      return decoded
          .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      _logger.e('Error loading conversations', e, stackTrace);
      return <ConversationModel>[];
    }
  }

  Future<void> _persist(List<ConversationModel> models) async {
    final list = models.map((m) => m.toJson()).toList();
    final jsonString = jsonEncode(list);
    await _prefs.setString(_conversationsKey, jsonString);
  }

  @override
  Future<void> saveConversation(ConversationModel conversation) async {
    try {
      final existing = await getConversations();
      final filtered =
          existing.where((c) => c.id != conversation.id).toList(growable: true);
      filtered.insert(0, conversation);
      await _persist(filtered);
      _logger.i('Conversation saved (id=${conversation.id}, type=${conversation.type})');
    } catch (e, stackTrace) {
      _logger.e('Error saving conversation', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> deleteConversation(String id) async {
    try {
      final existing = await getConversations();
      final filtered = existing.where((c) => c.id != id).toList();
      await _persist(filtered);
      _logger.i('Conversation deleted (id=$id)');
    } catch (e, stackTrace) {
      _logger.e('Error deleting conversation', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      await _prefs.remove(_conversationsKey);
      _logger.i('All conversations cleared');
    } catch (e, stackTrace) {
      _logger.e('Error clearing conversations', e, stackTrace);
      rethrow;
    }
  }
}
