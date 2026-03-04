import 'package:equatable/equatable.dart';

/// Type discriminator for [Conversation]. Same repository/datasource return all types.
enum ConversationType {
  express,
  proDealCloser,
}

/// Single message in a Pro Deal Closer conversation.
class ProDealCloserMessage extends Equatable {
  const ProDealCloserMessage({
    required this.text,
    this.attachmentPaths = const [],
  });

  final String text;
  final List<String> attachmentPaths;

  @override
  List<Object?> get props => [text, attachmentPaths];
}

/// Generic conversation; [type] segregates which fields are used.
/// Stored and returned by the same repository/datasource (e.g. API returns all).
class Conversation extends Equatable {
  const Conversation({
    required this.id,
    required this.type,
    this.screenshotPaths = const [],
    this.replyOptions = const [],
    this.keyword,
    this.messages = const [],
    required this.createdAt,
  });

  final String id;
  /// [ConversationType.express] or [ConversationType.proDealCloser]. Drives which payload is used.
  final ConversationType type;
  /// For [ConversationType.express].
  final List<String> screenshotPaths;
  final List<String> replyOptions;
  final String? keyword;
  /// For [ConversationType.proDealCloser].
  final List<ProDealCloserMessage> messages;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
        id,
        type,
        screenshotPaths,
        replyOptions,
        keyword,
        messages,
        createdAt,
      ];
}
