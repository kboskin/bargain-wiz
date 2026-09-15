import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:appwizard/features/pro_deal_closer/domain/entities/pro_conversation_title.dart';
import 'package:appwizard/features/pro_deal_closer/domain/repositories/pro_deal_closer_repository.dart';
import 'package:appwizard/features/pro_deal_closer/presentation/cubit/pro_deal_closer_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Pro Deal Closer chat state machine (mirror of the prototype's `proMsgs` /
/// `proTyping` store): user text or attachments → typing → one wizard reply →
/// optional "Give me options" (3 lines) / "Redo" (replace reply).
class ProDealCloserCubit extends Cubit<ProDealCloserState> {
  ProDealCloserCubit({
    required ProDealCloserRepository repository,
    required ConversationRepository conversationRepository,
    required AppLogger logger,
    this.uploadDelay = const Duration(milliseconds: 2000),
    String Function()? idGenerator,
  })  : _repository = repository,
        _conversations = conversationRepository,
        _logger = logger,
        _idGenerator = idGenerator ?? _defaultId,
        super(const ProDealCloserState());

  /// Pinned first wizard message.
  static const String greetingText = "What's the deal about?";

  final ProDealCloserRepository _repository;
  final ConversationRepository _conversations;
  final AppLogger _logger;
  final String Function() _idGenerator;

  /// Mock "reading" time for attachments before the wizard starts typing.
  final Duration uploadDelay;

  int _messageSeq = 0;
  int _replySeq = 0;

  static String _defaultId() => DateTime.now().millisecondsSinceEpoch.toString();

  String _nextMessageId() => 'm${_messageSeq++}_${DateTime.now().microsecondsSinceEpoch}';

  ProChatMessage _greeting({bool restored = false}) => ProChatMessage(
        id: _nextMessageId(),
        text: greetingText,
        isWizard: true,
        restored: restored,
      );

  /// Starts a fresh chat or restores [conversationId] from history.
  Future<void> start({
    required String vibe,
    required String locale,
    String? conversationId,
  }) async {
    emit(state.copyWith(status: ProDealCloserStatus.loading, vibe: vibe, locale: locale));

    if (conversationId == null) {
      emit(state.copyWith(status: ProDealCloserStatus.ready, messages: [_greeting()]));
      return;
    }

    final result = await _conversations.getConversations();
    if (isClosed) return;
    final conversation = result.fold(
      (failure) {
        _logger.w('ProDealCloserCubit: could not load conversations: ${failure.message}');
        return null;
      },
      (list) => list.where((c) => c.id == conversationId).firstOrNull,
    );

    if (conversation == null) {
      emit(state.copyWith(
        status: ProDealCloserStatus.ready,
        conversationId: conversationId,
        messages: [_greeting()],
      ));
      return;
    }

    final restored = conversation.messages
        .map((m) => ProChatMessage.fromEntity(m, id: _nextMessageId(), restored: true))
        .toList();
    if (restored.isEmpty || !restored.first.isWizard) {
      restored.insert(0, _greeting(restored: true));
    }
    emit(state.copyWith(
      status: ProDealCloserStatus.ready,
      conversationId: conversation.id,
      createdAt: conversation.createdAt,
      conversationStatus: conversation.status,
      messages: restored,
    ));
  }

  /// Tone used for subsequent replies (header chip).
  void setVibe(String vibe) {
    if (vibe == state.vibe) return;
    emit(state.copyWith(vibe: vibe));
  }

  /// Sends a user text line and requests the wizard reply.
  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final user = ProChatMessage(id: _nextMessageId(), text: trimmed);
    emit(state.copyWith(messages: [...state.messages, user], isTyping: true));
    await _requestReply();
  }

  /// Sends screenshots as one attachment bubble: "reading" for [uploadDelay],
  /// then the wizard types and replies.
  Future<void> sendAttachments(List<String> paths) async {
    if (paths.isEmpty) return;
    final id = _nextMessageId();
    final message = ProChatMessage(id: id, attachmentPaths: List<String>.from(paths), isUploading: true);
    emit(state.copyWith(messages: [...state.messages, message], isTyping: false));

    await Future<void>.delayed(uploadDelay);
    if (isClosed) return;
    emit(state.copyWith(
      messages: _update(id, (m) => m.copyWith(isUploading: false)),
      isTyping: true,
    ));
    await _requestReply();
  }

  /// "Give me options": attaches three lines to the wizard reply [messageId].
  Future<void> requestOptions(String messageId) async {
    final index = state.messages.indexWhere((m) => m.id == messageId);
    if (index < 0 || state.messages[index].optionsLoading) return;
    emit(state.copyWith(messages: _update(messageId, (m) => m.copyWith(optionsLoading: true))));

    final history = state.messages.sublist(0, index + 1).map((m) => m.toEntity()).toList();
    final result = await _repository.getOptions(
      history: history,
      vibe: state.vibe,
      locale: state.locale,
    );
    if (isClosed) return;
    result.fold(
      (failure) => _fail(
        failure,
        messages: _update(messageId, (m) => m.copyWith(optionsLoading: false)),
      ),
      (options) => emit(state.copyWith(
        messages: _update(
          messageId,
          (m) => m.copyWith(options: options, showActions: false, optionsLoading: false),
        ),
      )),
    );
  }

  /// "Redo": shows typing, then replaces the wizard reply [messageId].
  Future<void> redo(String messageId) async {
    final index = state.messages.indexWhere((m) => m.id == messageId);
    if (index < 0) return;
    final seq = ++_replySeq;
    emit(state.copyWith(isTyping: true));

    final history = state.messages.sublist(0, index).map((m) => m.toEntity()).toList();
    final result = await _repository.getReply(
      history: history,
      vibe: state.vibe,
      locale: state.locale,
      regenerate: true,
    );
    if (isClosed || seq != _replySeq) return;
    result.fold(
      _fail,
      (reply) => emit(state.copyWith(
        isTyping: false,
        messages: _update(
          messageId,
          (m) => m.copyWith(
            text: reply.text,
            options: const [],
            showActions: true,
            optionsLoading: false,
            restored: false,
          ),
        ),
      )),
    );
  }

  /// Persists the chat when the user sent at least one message.
  /// Returns true when saved. Reuses the conversation id on subsequent saves.
  Future<bool> save({String? marketplace}) async {
    if (!state.hasUserMessages) return false;
    final id = state.conversationId ?? _idGenerator();
    final createdAt = state.createdAt ?? DateTime.now();
    final messages = state.messages.map((m) => m.toEntity()).toList();
    final conversation = Conversation(
      id: id,
      type: ConversationType.proDealCloser,
      messages: messages,
      createdAt: createdAt,
      title: ProConversationTitle.derive(messages),
      marketplace: marketplace,
      status: state.conversationStatus,
      vibe: state.vibe,
    );
    final result = await _conversations.saveConversation(conversation);
    return result.fold(
      (failure) {
        _logger.w('ProDealCloserCubit: save failed: ${failure.message}');
        return false;
      },
      (_) {
        if (!isClosed) emit(state.copyWith(conversationId: id, createdAt: createdAt));
        return true;
      },
    );
  }

  Future<void> _requestReply() async {
    final seq = ++_replySeq;
    final history = state.messages.map((m) => m.toEntity()).toList();
    final result = await _repository.getReply(
      history: history,
      vibe: state.vibe,
      locale: state.locale,
    );
    // A newer message superseded this request (prototype clears the pending reply timer).
    if (isClosed || seq != _replySeq) return;
    result.fold(
      _fail,
      (reply) => emit(state.copyWith(
        isTyping: false,
        messages: [
          ...state.messages,
          ProChatMessage(
            id: _nextMessageId(),
            text: reply.text,
            isWizard: true,
            showActions: true,
          ),
        ],
      )),
    );
  }

  void _fail(Failure failure, {List<ProChatMessage>? messages}) {
    _logger.w('ProDealCloserCubit: request failed: ${failure.message}');
    emit(state.copyWith(
      isTyping: false,
      messages: messages,
      failure: failure,
      errorCount: state.errorCount + 1,
    ));
  }

  List<ProChatMessage> _update(String id, ProChatMessage Function(ProChatMessage) change) =>
      [for (final m in state.messages) if (m.id == id) change(m) else m];
}
