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
    this.vibe = '',
    this.locale = 'en',
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
  /// Current tone id used for requests.
  final String vibe;
  final String locale;
  /// Last failure; [errorCount] increments on each new one so listeners can react.
  final Failure? failure;
  final int errorCount;

  bool get hasUserMessages => messages.any((m) => m.isUser);

  ProChatMessage? messageById(String id) => messages.where((m) => m.id == id).firstOrNull;

  ProDealCloserState copyWith({
    ProDealCloserStatus? status,
    Object? conversationId = _unset,
    Object? createdAt = _unset,
    ConversationStatus? conversationStatus,
    List<ProChatMessage>? messages,
    bool? isTyping,
    String? vibe,
    String? locale,
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
        vibe: vibe ?? this.vibe,
        locale: locale ?? this.locale,
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
        vibe,
        locale,
        failure,
        errorCount,
      ];
}
