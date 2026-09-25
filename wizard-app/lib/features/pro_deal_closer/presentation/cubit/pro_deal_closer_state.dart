import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:equatable/equatable.dart';

const Object _unset = Object();

/// One chat row in the Pro Deal Closer screen: the persisted
/// [ProDealCloserMessage] plus transient UI flags.
class ProChatMessage extends Equatable {
  const ProChatMessage({
    required this.id,
    this.text = '',
    this.attachmentPaths = const [],
    this.isWizard = false,
    this.options = const [],
    this.isUploading = false,
    this.showActions = false,
    this.optionsLoading = false,
    this.restored = false,
    this.status = MessageStatus.done,
  });

  /// [localPaths] are this device's files for a turn it sent (server refs otherwise).
  factory ProChatMessage.fromEntity(
    ProDealCloserMessage entity, {
    required String id,
    bool restored = false,
    List<String>? localPaths,
  }) =>
      ProChatMessage(
        id: id,
        text: entity.isWizard && entity.isFailed && entity.text.isEmpty
            ? (entity.errorMessage ?? 'The wizard could not answer. Try again.')
            : entity.text,
        attachmentPaths: List<String>.from(localPaths ?? entity.displayPaths),
        isWizard: entity.isWizard,
        options: List<DealLine>.from(entity.options),
        restored: restored,
        status: entity.status,
      );

  /// Stable key for list items / per-row widget state.
  final String id;
  final String text;
  final List<String> attachmentPaths;
  final bool isWizard;
  /// "Give me options" lines attached to a wizard reply.
  final List<DealLine> options;
  /// User attachment message still being "read" (scan line + reading label).
  final bool isUploading;
  /// Wizard reply still offering the "Give me options" / "Redo" row.
  final bool showActions;
  final bool optionsLoading;
  /// Loaded from history: rendered without entrance animation, actions hidden.
  final bool restored;
  /// Server lifecycle (pending = typing placeholder, failed = needs a Redo / resend).
  final MessageStatus status;

  bool get isUser => !isWizard;
  bool get hasAttachments => attachmentPaths.isNotEmpty;
  bool get isFailed => status == MessageStatus.failed;

  ProDealCloserMessage toEntity() => ProDealCloserMessage(
        text: text,
        attachmentPaths: attachmentPaths,
        isWizard: isWizard,
        options: options,
      );

  ProChatMessage copyWith({
    String? text,
    List<String>? attachmentPaths,
    bool? isWizard,
    List<DealLine>? options,
    bool? isUploading,
    bool? showActions,
    bool? optionsLoading,
    bool? restored,
    MessageStatus? status,
  }) =>
      ProChatMessage(
        id: id,
        text: text ?? this.text,
        attachmentPaths: attachmentPaths ?? this.attachmentPaths,
        isWizard: isWizard ?? this.isWizard,
        options: options ?? this.options,
        isUploading: isUploading ?? this.isUploading,
        showActions: showActions ?? this.showActions,
        optionsLoading: optionsLoading ?? this.optionsLoading,
        restored: restored ?? this.restored,
        status: status ?? this.status,
      );

  @override
  List<Object?> get props => [
        id,
        text,
        attachmentPaths,
        isWizard,
        options,
        isUploading,
        showActions,
        optionsLoading,
        restored,
        status,
      ];
}

enum ProDealCloserStatus { initial, loading, ready }

class ProDealCloserState extends Equatable {
  const ProDealCloserState({
    this.status = ProDealCloserStatus.initial,
    this.conversationId,
    this.createdAt,
    this.conversationStatus = ConversationStatus.open,
    this.messages = const [],
    this.isTyping = false,
    this.overrides = const {},
    this.locale = 'en',
    this.objective,
    this.failure,
    this.errorCount = 0,
  });

  final ProDealCloserStatus status;
  /// Id of the saved conversation (set when reopened from history or after the first save).
  final String? conversationId;
  final DateTime? createdAt;
  /// Preserved when reopening a conversation (open / won / lost).
  final ConversationStatus conversationStatus;
  final List<ProChatMessage> messages;
  /// Wizard typing indicator visible.
  final bool isTyping;
  /// The conversation-scoped answers this deal overrides, `{answer key: value}`. Sent with
  /// every request and saved with the deal, so reopening it coaches in the voice it was
  /// written in rather than in whatever the profile default has since become.
  final Map<String, dynamic> overrides;
  final String locale;
  /// What this chat is for — the objective's text — or none. It belongs to the conversation:
  /// sent with the request that creates it, read back on reopen.
  final String? objective;
  /// Last failure; [errorCount] increments on each new one so listeners can react.
  final Failure? failure;
  final int errorCount;

  bool get hasUserMessages => messages.any((m) => m.isUser);

  /// The objective can change until the chat exists: the first turn is in flight or done
  /// once [isTyping] or a [conversationId] says so. A first send that failed leaves it open.
  bool get canPickObjective => conversationId == null && !isTyping;

  ProChatMessage? messageById(String id) => messages.where((m) => m.id == id).firstOrNull;

  ProDealCloserState copyWith({
    ProDealCloserStatus? status,
    Object? conversationId = _unset,
    Object? createdAt = _unset,
    ConversationStatus? conversationStatus,
    List<ProChatMessage>? messages,
    bool? isTyping,
    Map<String, dynamic>? overrides,
    String? locale,
    Object? objective = _unset,
    Object? failure = _unset,
    int? errorCount,
  }) =>
      ProDealCloserState(
        status: status ?? this.status,
        conversationId: conversationId == _unset ? this.conversationId : conversationId as String?,
        createdAt: createdAt == _unset ? this.createdAt : createdAt as DateTime?,
        conversationStatus: conversationStatus ?? this.conversationStatus,
        messages: messages ?? this.messages,
        isTyping: isTyping ?? this.isTyping,
        overrides: overrides ?? this.overrides,
        locale: locale ?? this.locale,
        objective: objective == _unset ? this.objective : objective as String?,
        failure: failure == _unset ? this.failure : failure as Failure?,
        errorCount: errorCount ?? this.errorCount,
      );

  @override
  List<Object?> get props => [
        status,
        conversationId,
        createdAt,
        conversationStatus,
        messages,
        isTyping,
        overrides,
        locale,
        objective,
        failure,
        errorCount,
      ];
}
