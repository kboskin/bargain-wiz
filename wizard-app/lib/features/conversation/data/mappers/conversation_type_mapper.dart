import 'package:appwizard/features/conversation/domain/entities/conversation.dart';

/// Maps [ConversationType] enum to/from persisted string (e.g. API, SharedPreferences).
class ConversationTypeMapper {
  static const String _express = 'express';
  static const String _proDealCloser = 'pro_deal_closer';

  ConversationType toEntity(String? value) {
    if (value == _proDealCloser) return ConversationType.proDealCloser;
    return ConversationType.express;
  }

  String toModel(ConversationType type) {
    switch (type) {
      case ConversationType.express:
        return _express;
      case ConversationType.proDealCloser:
        return _proDealCloser;
    }
  }
}
