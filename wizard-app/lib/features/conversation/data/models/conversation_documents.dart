import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import 'package:appwizard/features/conversation/domain/entities/conversation.dart';

/// Firestore documents written by the `conversations` function → domain entities.
/// Field names follow the backend (snake_case); every field is optional on read so an older
/// app keeps working when the schema grows.
class ConversationDocuments {
  const ConversationDocuments._();

  static Conversation conversation(String id, Map<String, dynamic> data) {
    final express = _map(data['express']);
    final thumbnail = attachment(data['thumbnail']);
    final createdAt = date(data['created_at']);
    return Conversation(
      id: id,
      type: data['type'] == 'express' ? ConversationType.express : ConversationType.proDealCloser,
      screenshotPaths: [for (final ref in attachments(express?['images'])) ref.storagePath],
      replyLines: lines(express?['lines']),
      createdAt: createdAt ?? date(data['updated_at']) ?? DateTime.now(),
      updatedAt: date(data['updated_at']),
      title: string(data['title']),
      status: ConversationStatus.fromString(string(data['status'])),
      priceBefore: string(data['price_before']),
      priceAfter: string(data['price_after']),
      seeing: string(express?['seeing']),
      keyword: string(express?['keyword'] ?? data['keyword']),
      overrides: _map(data['overrides']),
      objective: string(data['objective']),
      preview: string(data['preview']),
      thumbnailStoragePath: thumbnail?.storagePath,
      messageCount: (data['message_count'] as num?)?.toInt() ?? 0,
      isTyping: data['active_turn'] != null,
      errorMessage: string(_map(data['last_error'])?['message']),
    );
  }

  /// The seq-0 record of the system prompt the conversation started with. The app never
  /// renders it — see `watchMessages` — but it is part of the stored transcript so a deal
  /// can be read back as the model saw it (CONVERSATIONS.md).
  static bool isSystem(Map<String, dynamic> data) => data['role'] == 'system';

  static ProDealCloserMessage message(String id, Map<String, dynamic> data) {
    final error = _map(data['error']);
    final optionsError = _map(data['options_error']);
    return ProDealCloserMessage(
      id: id,
      text: string(data['text']) ?? '',
      attachments: attachments(data['images']),
      // The wire uses Gemini's role vocabulary ('user' | 'model'); the UI keeps the
      // product's word for the same thing.
      isWizard: data['role'] == 'model',
      options: lines(data['lines']),
      status: MessageStatus.fromString(string(data['status'])),
      revision: (data['revision'] as num?)?.toInt() ?? 0,
      seq: (data['seq'] as num?)?.toInt() ?? 0,
      errorMessage: string(error?['message']),
      pendingOptions: data['pending_options'] == true,
      optionsError: string(optionsError?['message']),
    );
  }

  static ChatAttachment? attachment(Object? raw) {
    final map = _map(raw);
    final path = string(map?['path']);
    if (path == null) return null;
    return ChatAttachment(
      storagePath: path,
      width: (map?['width'] as num?)?.toInt(),
      height: (map?['height'] as num?)?.toInt(),
    );
  }

  static List<ChatAttachment> attachments(Object? raw) => [
        if (raw is List)
          for (final item in raw)
            if (attachment(item) case final ref?) ref,
      ];

  static List<DealLine> lines(Object? raw) => [
        if (raw is List)
          for (final item in raw)
            if (item is Map && (item['text']?.toString() ?? '').isNotEmpty) DealLine.fromDynamic(item),
      ];

  static DateTime? date(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  static String? string(Object? raw) {
    if (raw == null) return null;
    final text = raw.toString();
    return text.isEmpty ? null : text;
  }

  static Map<String, dynamic>? _map(Object? raw) => raw is Map ? Map<String, dynamic>.from(raw) : null;
}
