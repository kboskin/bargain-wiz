import 'package:equatable/equatable.dart';
import 'package:appwizard/features/conversation/domain/entities/deal_line.dart';

export 'package:appwizard/features/conversation/domain/entities/deal_line.dart';

/// Type discriminator for [Conversation]. Same repository/datasource return all types.
enum ConversationType {
  express,
  proDealCloser,
}

/// Outcome of a saved negotiation (Bargains History filter chips).
enum ConversationStatus {
  open,
  won,
  lost;

  static ConversationStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'won':
        return ConversationStatus.won;
      case 'lost':
        return ConversationStatus.lost;
      default:
        return ConversationStatus.open;
    }
  }
}

/// Lifecycle of a wizard turn stored by the backend (CONVERSATIONS.md): the placeholder is
/// [pending] while the model works, [failed] when it could not answer, otherwise [done].
enum MessageStatus {
  pending,
  done,
  failed;

  static MessageStatus fromString(String? value) {
    switch (value) {
      case 'pending':
        return MessageStatus.pending;
      case 'failed':
        return MessageStatus.failed;
      default:
        return MessageStatus.done;
    }
  }
}

/// A screenshot the backend stored in Cloud Storage, plus the local file when it was picked
/// on this device (so fresh chats render without a download).
class ChatAttachment extends Equatable {
  const ChatAttachment({required this.storagePath, this.localPath, this.width, this.height});

  /// Cloud Storage object path (`users/{uid}/conversations/{cid}/{id}.jpg`).
  final String storagePath;
  final String? localPath;
  final int? width;
  final int? height;

  /// What to render: the local file when we have it, else the stored object.
  String get displayPath => localPath ?? storagePath;

  @override
  List<Object?> get props => [storagePath, localPath, width, height];
}

/// Single message in a Pro Deal Closer conversation.
/// [isWizard] marks assistant messages; [options] holds the "Give me options"
/// lines attached to a wizard reply once requested.
class ProDealCloserMessage extends Equatable {
  const ProDealCloserMessage({
    this.id = '',
    required this.text,
    this.attachmentPaths = const [],
    this.attachments = const [],
    this.isWizard = false,
    this.options = const [],
    this.status = MessageStatus.done,
    this.revision = 0,
    this.seq = 0,
    this.errorMessage,
    this.pendingOptions = false,
    this.optionsError,
  });

  /// Firestore document id; empty for a message that only exists on this device.
  final String id;
  final String text;
  /// Local screenshot files (picked on this device).
  final List<String> attachmentPaths;
  /// Screenshots as stored by the backend.
  final List<ChatAttachment> attachments;
  final bool isWizard;
  final List<DealLine> options;
  final MessageStatus status;
  /// Incremented by every "Redo".
  final int revision;
  /// Server-assigned order within the conversation.
  final int seq;
  /// User-safe error text when [status] is [MessageStatus.failed].
  final String? errorMessage;
  /// "Give me options" is queued or running for this reply (survives an app restart).
  final bool pendingOptions;
  /// User-safe error text when the last options request failed.
  final String? optionsError;

  /// Convenience inverse of [isWizard].
  bool get isUser => !isWizard;
  bool get isPending => status == MessageStatus.pending;
  bool get isFailed => status == MessageStatus.failed;
  bool get hasAttachments => attachmentPaths.isNotEmpty || attachments.isNotEmpty;

  /// Paths to render: local files when we have them, else the stored objects.
  List<String> get displayPaths =>
      attachmentPaths.isNotEmpty ? attachmentPaths : [for (final a in attachments) a.displayPath];

  ProDealCloserMessage copyWith({
    String? id,
    String? text,
    List<String>? attachmentPaths,
    List<ChatAttachment>? attachments,
    bool? isWizard,
    List<DealLine>? options,
    MessageStatus? status,
    int? revision,
    int? seq,
    String? errorMessage,
    bool? pendingOptions,
    String? optionsError,
  }) =>
      ProDealCloserMessage(
        id: id ?? this.id,
        text: text ?? this.text,
        attachmentPaths: attachmentPaths ?? this.attachmentPaths,
        attachments: attachments ?? this.attachments,
        isWizard: isWizard ?? this.isWizard,
        options: options ?? this.options,
        status: status ?? this.status,
        revision: revision ?? this.revision,
        seq: seq ?? this.seq,
        errorMessage: errorMessage ?? this.errorMessage,
        pendingOptions: pendingOptions ?? this.pendingOptions,
        optionsError: optionsError ?? this.optionsError,
      );

  @override
  List<Object?> get props => [id, text, attachmentPaths, attachments, isWizard, options, status,
        revision, seq, errorMessage, pendingOptions, optionsError];
}

/// Generic conversation; [type] segregates which fields are used.
/// Read from the backend's Firestore documents (CONVERSATIONS.md); written only through the
/// `conversations` function.
class Conversation extends Equatable {
  const Conversation({
    required this.id,
    required this.type,
    this.screenshotPaths = const [],
    this.replyOptions = const [],
    this.replyLines = const [],
    this.keyword,
    this.messages = const [],
    required this.createdAt,
    this.updatedAt,
    this.title,
    this.status = ConversationStatus.open,
    this.priceBefore,
    this.priceAfter,
    this.seeing,
    this.overrides,
    this.preview,
    this.thumbnailStoragePath,
    this.messageCount = 0,
    this.isTyping = false,
    this.errorMessage,
  });

  final String id;
  /// [ConversationType.express] or [ConversationType.proDealCloser]. Drives which payload is used.
  final ConversationType type;
  /// For [ConversationType.express]: local files while the deal is fresh, Cloud Storage paths
  /// when read back from the backend.
  final List<String> screenshotPaths;
  /// Legacy flat reply strings (kept for backward compatibility with saved data).
  final List<String> replyOptions;
  /// Structured reply lines with intent + why. Preferred over [replyOptions].
  final List<DealLine> replyLines;
  final String? keyword;
  /// For [ConversationType.proDealCloser] (only filled when messages were loaded).
  final List<ProDealCloserMessage> messages;
  final DateTime createdAt;
  /// Last activity on the server.
  final DateTime? updatedAt;

  // ── History metadata (Bargains History screen) ──
  /// Auto-generated from the screenshot / first message when null.
  final String? title;
  final ConversationStatus status;
  /// Free-form price strings, e.g. "$420" → "$365".
  final String? priceBefore;
  final String? priceAfter;
  /// What the wizard "saw" in the screenshots (Express results strip).
  final String? seeing;

  /// The conversation-scoped answers this deal carries, `{answer key: value}` — the ones
  /// the template marks `scope: "conversation"`, snapshotted when the deal was opened and
  /// edited by the chips in its header. Reopening a deal coaches from these, not from the
  /// profile, so the thread keeps the voice it was written in (CONVERSATIONS.md).
  final Map<String, dynamic>? overrides;
  /// Last message text, clipped by the server.
  final String? preview;
  /// First screenshot stored for this deal (Cloud Storage path).
  final String? thumbnailStoragePath;
  final int messageCount;
  /// A wizard reply is being generated right now (server `active_turn`).
  final bool isTyping;
  /// User-safe text of the last generation failure (server `last_error`); cleared on the next
  /// success. Express reads its outcome from this document, so without it a failed deal is
  /// indistinguishable from an empty one.
  final String? errorMessage;

  /// Effective reply lines: structured when available, else legacy strings.
  List<DealLine> get effectiveLines => replyLines.isNotEmpty
      ? replyLines
      : replyOptions.map((t) => DealLine(text: t)).toList();

  /// First image usable as a thumbnail: a local screenshot, a chat attachment, or the
  /// server-stored thumbnail. Render with `AttachmentImage`, which handles both kinds of path.
  String? get thumbnailPath {
    if (screenshotPaths.isNotEmpty) return screenshotPaths.first;
    for (final m in messages) {
      final paths = m.displayPaths;
      if (paths.isNotEmpty) return paths.first;
    }
    return thumbnailStoragePath;
  }

  /// Time to order history by (last activity, else creation).
  DateTime get sortedAt => updatedAt ?? createdAt;

  Conversation copyWith({
    String? id,
    ConversationType? type,
    List<String>? screenshotPaths,
    List<String>? replyOptions,
    List<DealLine>? replyLines,
    String? keyword,
    List<ProDealCloserMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? title,
    ConversationStatus? status,
    String? priceBefore,
    String? priceAfter,
    String? seeing,
    Map<String, dynamic>? overrides,
    String? preview,
    String? thumbnailStoragePath,
    int? messageCount,
    bool? isTyping,
    String? errorMessage,
  }) =>
      Conversation(
        id: id ?? this.id,
        type: type ?? this.type,
        screenshotPaths: screenshotPaths ?? this.screenshotPaths,
        replyOptions: replyOptions ?? this.replyOptions,
        replyLines: replyLines ?? this.replyLines,
        keyword: keyword ?? this.keyword,
        messages: messages ?? this.messages,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        title: title ?? this.title,
        status: status ?? this.status,
        priceBefore: priceBefore ?? this.priceBefore,
        priceAfter: priceAfter ?? this.priceAfter,
        seeing: seeing ?? this.seeing,
        overrides: overrides ?? this.overrides,
        preview: preview ?? this.preview,
        thumbnailStoragePath: thumbnailStoragePath ?? this.thumbnailStoragePath,
        messageCount: messageCount ?? this.messageCount,
        isTyping: isTyping ?? this.isTyping,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  @override
  List<Object?> get props => [
        id,
        type,
        screenshotPaths,
        replyOptions,
        replyLines,
        keyword,
        messages,
        createdAt,
        updatedAt,
        title,
        status,
        priceBefore,
        priceAfter,
        seeing,
        overrides,
        preview,
        thumbnailStoragePath,
        messageCount,
        isTyping,
        errorMessage,
      ];
}
