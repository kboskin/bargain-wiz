import 'dart:async';
import 'dart:math';

import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/core/services/installation_id_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:appwizard/features/pro_deal_closer/domain/repositories/pro_deal_closer_repository.dart';
import 'package:appwizard/features/pro_deal_closer/presentation/cubit/pro_deal_closer_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Pro Deal Closer chat: a projection of the backend-owned conversation
/// (CONVERSATIONS.md §5) plus optimistic bubbles for what this device just sent.
///
/// The server list (from [ProDealCloserRepository.watchMessages]) is the truth: a wizard
/// message that is still `pending` is the typing indicator, `failed` renders with a Redo.
/// A user bubble is shown immediately with its `request_id` and dropped once the server
/// echoes a message with the same id.
class ProDealCloserCubit extends Cubit<ProDealCloserState> {
  ProDealCloserCubit({
    required ProDealCloserRepository repository,
    required ConversationRepository conversationRepository,
    required AppLogger logger,
    String Function()? requestIdGenerator,
  })  : _repository = repository,
        _conversations = conversationRepository,
        _logger = logger,
        _requestId = requestIdGenerator ?? _uuid,
        super(const ProDealCloserState());

  /// Pinned first wizard message (local only, never stored).
  static const String greetingText = "What's the deal about?";
  static const String greetingId = 'greeting';
  static const String failedReplyText = 'The wizard could not answer. Try again.';

  final ProDealCloserRepository _repository;
  final ConversationRepository _conversations;
  final AppLogger _logger;
  final String Function() _requestId;

  StreamSubscription<List<ProDealCloserMessage>>? _subscription;
  List<ProDealCloserMessage> _server = const [];
  /// Bubbles sent from this device that the server has not echoed yet, by request id.
  final Map<String, ProChatMessage> _optimistic = {};
  /// Local screenshot files per request id, so fresh attachments render without a download.
  final Map<String, List<String>> _localPaths = {};
  final Set<String> _optionsLoading = {};
  /// Messages that existed when a saved chat was reopened: no entrance animation, no actions.
  Set<String> _restoredIds = const {};
  bool _awaitingRestoreSnapshot = false;

  static String _uuid() => InstallationIdService.generate(Random.secure());

  /// Starts a fresh chat or reopens [conversationId] from history.
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
    final found = await _conversations.findById(conversationId);
    if (isClosed) return;
    final conversation = found.fold((failure) {
      _logger.w('ProDealCloserCubit: could not load conversation: ${failure.message}');
      return null;
    }, (c) => c);
    _awaitingRestoreSnapshot = true;
    emit(state.copyWith(
      status: ProDealCloserStatus.ready,
      conversationId: conversationId,
      createdAt: conversation?.createdAt,
      conversationStatus: conversation?.status ?? ConversationStatus.open,
      messages: [_greeting(restored: true)],
    ));
    _subscribe(conversationId);
  }

  /// Tone used for subsequent replies (header chip).
  void setVibe(String vibe) {
    if (vibe == state.vibe) return;
    emit(state.copyWith(vibe: vibe));
  }

  /// Sends a user text line; the wizard reply arrives through the listener.
  Future<void> sendText(String text) => _send(text: text.trim());

  /// Sends screenshots as one attachment bubble ("Reading…" until the server has them).
  Future<void> sendAttachments(List<String> paths) => _send(paths: List<String>.from(paths));

  Future<void> _send({String text = '', List<String> paths = const []}) async {
    if (text.isEmpty && paths.isEmpty) return;
    if (state.isTyping) return; // the server takes one turn at a time (409 otherwise)
    final requestId = _requestId();
    final local = ProChatMessage(
      id: 'local_$requestId',
      text: text,
      attachmentPaths: paths,
      isUploading: paths.isNotEmpty,
      requestId: requestId,
    );
    _optimistic[requestId] = local;
    if (paths.isNotEmpty) _localPaths[requestId] = paths;
    _rebuild();

    final result = await _repository.send(
      conversationId: state.conversationId,
      requestId: requestId,
      text: text.isEmpty ? null : text,
      attachmentPaths: paths,
      vibe: state.vibe,
      locale: state.locale,
    );
    if (isClosed) return;
    result.fold(
      (failure) {
        _optimistic[requestId] = local.copyWith(isUploading: false, status: MessageStatus.failed);
        _fail(failure);
      },
      (sent) {
        if (state.conversationId == null) {
          emit(state.copyWith(conversationId: sent.conversationId, createdAt: state.createdAt ?? DateTime.now()));
          _subscribe(sent.conversationId);
        }
      },
    );
  }

  /// "Give me options": attaches three lines to the wizard reply [messageId].
  Future<void> requestOptions(String messageId) async {
    final conversationId = state.conversationId;
    if (conversationId == null || _optionsLoading.contains(messageId)) return;
    _optionsLoading.add(messageId);
    _rebuild();
    final result = await _repository.requestOptions(
      conversationId: conversationId,
      messageId: messageId,
      requestId: _requestId(),
      vibe: state.vibe,
      locale: state.locale,
    );
    if (isClosed) return;
    _optionsLoading.remove(messageId);
    result.fold(_fail, (lines) {
      // Apply right away; the listener confirms with the same lines.
      _server = [for (final m in _server) m.id == messageId ? m.copyWith(options: lines) : m];
      _rebuild();
    });
  }

  /// "Redo": the server marks [messageId] pending (typing) and replaces its text.
  Future<void> redo(String messageId) async {
    final conversationId = state.conversationId;
    if (conversationId == null || state.isTyping) return;
    final result = await _repository.redo(
      conversationId: conversationId,
      messageId: messageId,
      requestId: _requestId(),
      vibe: state.vibe,
      locale: state.locale,
    );
    if (isClosed) return;
    result.fold(_fail, (_) {});
  }

  /// Persists history metadata (vibe, marketplace, status) when the chat exists on the server.
  /// Returns true when saved. Messages themselves are already there.
  Future<bool> save({String? marketplace}) async {
    final conversationId = state.conversationId;
    if (conversationId == null) return false;
    final result = await _conversations.saveConversation(Conversation(
      id: conversationId,
      type: ConversationType.proDealCloser,
      createdAt: state.createdAt ?? DateTime.now(),
      status: state.conversationStatus,
      vibe: state.vibe,
      marketplace: marketplace,
    ));
    return result.fold((failure) {
      _logger.w('ProDealCloserCubit: save failed: ${failure.message}');
      return false;
    }, (_) => true);
  }

  void _subscribe(String conversationId) {
    unawaited(_subscription?.cancel());
    _subscription = _repository.watchMessages(conversationId).listen(
      _onServerMessages,
      onError: (Object e, StackTrace stackTrace) {
        _logger.e('ProDealCloserCubit: listener failed', e, stackTrace);
        if (!isClosed) _fail(ServerFailure(e.toString()));
      },
    );
  }

  void _onServerMessages(List<ProDealCloserMessage> messages) {
    if (isClosed) return;
    _server = messages;
    if (_awaitingRestoreSnapshot) {
      _restoredIds = {for (final m in messages) m.id};
      _awaitingRestoreSnapshot = false;
    }
    for (final m in messages) {
      final requestId = m.requestId;
      if (requestId != null) _optimistic.remove(requestId);
    }
    _rebuild();
  }

  void _rebuild({Failure? failure}) {
    final rows = <ProChatMessage>[_greeting(restored: _restoredIds.isNotEmpty)];
    final lastWizardId = _server.where((m) => m.isWizard).lastOrNull?.id;
    for (final m in _server) {
      final requestId = m.requestId;
      final restored = _restoredIds.contains(m.id);
      rows.add(
        ProChatMessage.fromEntity(
          m,
          id: m.id,
          restored: restored,
          localPaths: requestId == null ? null : _localPaths[requestId],
        ).copyWith(
          showActions: m.isWizard && m.id == lastWizardId && !m.isPending && !restored && m.options.isEmpty,
          optionsLoading: _optionsLoading.contains(m.id),
        ),
      );
    }
    rows.addAll(_optimistic.values);
    final typing = _server.any((m) => m.isWizard && m.isPending) || _optimistic.values.any((m) => !m.isFailed);
    emit(state.copyWith(
      messages: rows,
      isTyping: typing,
      failure: failure,
      errorCount: failure == null ? state.errorCount : state.errorCount + 1,
    ));
  }

  void _fail(Failure failure) {
    _logger.w('ProDealCloserCubit: request failed: ${failure.message}');
    _rebuild(failure: failure);
  }

  ProChatMessage _greeting({bool restored = false}) =>
      ProChatMessage(id: greetingId, text: greetingText, isWizard: true, restored: restored);

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
