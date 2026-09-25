import 'dart:async';

import 'package:appwizard/core/error/failures.dart';
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
/// A user bubble is shown immediately and retired when the echo lands — [send] and the
/// server both allow one turn at a time, so the first new user message to arrive is
/// necessarily the one in flight and no correlation id is needed to recognise it.
class ProDealCloserCubit extends Cubit<ProDealCloserState> {
  ProDealCloserCubit({
    required ProDealCloserRepository repository,
    required ConversationRepository conversationRepository,
    required AppLogger logger,
  })  : _repository = repository,
        _conversations = conversationRepository,
        _logger = logger,
        super(const ProDealCloserState());

  /// Pinned first wizard message (local only, never stored).
  static const String greetingText = "What's the deal about?";
  static const String greetingId = 'greeting';
  static const String failedReplyText = 'The wizard could not answer. Try again.';

  final ProDealCloserRepository _repository;
  final ConversationRepository _conversations;
  final AppLogger _logger;

  StreamSubscription<List<ProDealCloserMessage>>? _subscription;
  List<ProDealCloserMessage> _server = const [];
  /// The turn this device has in flight, shown before the server echoes it. At most one:
  /// [send] bails while typing and the server answers 409 for a second one.
  ProChatMessage? _inFlight;
  /// User messages the server had when [_inFlight] was sent; a higher count means the echo
  /// arrived and the local bubble can go.
  int _serverUserCountAtSend = 0;
  /// Sends that failed, kept on screen with a failed status until the chat is left.
  final List<ProChatMessage> _failed = [];
  /// Local screenshot files by server message id, so a just-sent attachment renders from
  /// disk instead of being downloaded back from Storage.
  final Map<String, List<String>> _localPaths = {};
  /// Ids whose options request is still in flight over HTTP; once the server has it, the
  /// message's own `pendingOptions` keeps the spinner going.
  final Set<String> _optionsLoading = {};
  /// Options failures already reported, so a toast fires once per failure.
  final Set<String> _reportedOptionErrors = {};
  /// Messages that existed when a saved chat was reopened: no entrance animation, no actions.
  Set<String> _restoredIds = const {};
  bool _awaitingRestoreSnapshot = false;

  /// Starts a fresh chat or reopens [conversationId] from history.
  Future<void> start({
    required Map<String, dynamic> overrides,
    required String locale,
    String? conversationId,
  }) async {
    emit(state.copyWith(status: ProDealCloserStatus.loading, overrides: overrides, locale: locale));
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
      // A reopened thread keeps the answers it was written with, not today's profile
      // defaults — the transcript above was coached in that voice (CONVERSATIONS.md).
      overrides: conversation?.overrides,
      objective: conversation?.objective,
      messages: [_greeting(restored: true)],
    ));
    _subscribe(conversationId);
  }

  /// Sends one turn — what the composer holds when Send is tapped: the typed [text] and the
  /// staged screenshot [paths] together, either of which may be empty. The screenshots show
  /// as one bubble ("Reading…" until the server has them); the wizard reply arrives through
  /// the listener.
  Future<void> send({final String text = '', final List<String> paths = const []}) =>
      _send(text: text.trim(), paths: List<String>.from(paths));

  /// Picks the objective this chat is for — or, tapping the picked one again, none. Only
  /// until the chat exists: it goes out with the request that creates the conversation, and
  /// the conversation keeps it for every later turn.
  void selectObjective(final String objective) {
    if (!state.canPickObjective) return;
    emit(state.copyWith(objective: state.objective == objective ? null : objective));
  }

  Future<void> _send({required final String text, required final List<String> paths}) async {
    if (text.isEmpty && paths.isEmpty) return;
    if (state.isTyping) return; // the server takes one turn at a time (409 otherwise)
    final local = ProChatMessage(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      attachmentPaths: paths,
      isUploading: paths.isNotEmpty,
    );
    _inFlight = local;
    _serverUserCountAtSend = _server.where((m) => m.isUser).length;
    _rebuild();

    final result = await _repository.send(
      conversationId: state.conversationId,
      text: text.isEmpty ? null : text,
      attachmentPaths: paths,
      overrides: state.overrides,
      locale: state.locale,
      objective: state.objective,
    );
    if (isClosed) return;
    result.fold(
      (failure) {
        _inFlight = null;
        _failed.add(local.copyWith(isUploading: false, status: MessageStatus.failed));
        _fail(failure);
      },
      (sent) {
        // The response names the stored turn, so the screenshots just picked can keep
        // rendering from disk. When the echo wins the race the tile downloads once and this
        // rebuild puts the local file back.
        final messageId = sent.messageId;
        if (paths.isNotEmpty && messageId != null) _localPaths[messageId] = paths;
        if (state.conversationId == null) {
          emit(state.copyWith(conversationId: sent.conversationId, createdAt: state.createdAt ?? DateTime.now()));
          _subscribe(sent.conversationId);
        } else if (paths.isNotEmpty) {
          _rebuild();
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
      overrides: state.overrides,
      locale: state.locale,
    );
    if (isClosed) return;
    // The server now owns the spinner (`pendingOptions`) and will write the lines.
    _optionsLoading.remove(messageId);
    result.fold(_fail, (_) => _rebuild());
  }

  /// "Redo": the server marks [messageId] pending (typing) and replaces its text.
  Future<void> redo(String messageId) async {
    final conversationId = state.conversationId;
    if (conversationId == null || state.isTyping) return;
    final result = await _repository.redo(
      conversationId: conversationId,
      messageId: messageId,
      overrides: state.overrides,
      locale: state.locale,
    );
    if (isClosed) return;
    result.fold(_fail, (_) {});
  }

  /// Persists history metadata (the deal's overrides and status) when the chat exists on
  /// the server. Returns true when saved. Messages themselves are already there.
  Future<bool> save() async {
    final conversationId = state.conversationId;
    if (conversationId == null) return false;
    final result = await _conversations.saveConversation(Conversation(
      id: conversationId,
      type: ConversationType.proDealCloser,
      createdAt: state.createdAt ?? DateTime.now(),
      status: state.conversationStatus,
      overrides: state.overrides,
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
    // One turn is outstanding at a time, so a user message the server did not have when we
    // sent is that turn: the local bubble has been replaced and can go.
    if (_inFlight != null && messages.where((m) => m.isUser).length > _serverUserCountAtSend) {
      _inFlight = null;
    }
    _rebuild();
  }

  void _rebuild({Failure? failure}) {
    failure ??= _newOptionsFailure();
    final rows = <ProChatMessage>[_greeting(restored: _restoredIds.isNotEmpty)];
    final lastWizardId = _server.where((m) => m.isWizard).lastOrNull?.id;
    for (final m in _server) {
      // A pending wizard message is the placeholder the worker will fill: the typing bubble
      // stands in for it, so rendering it too would show an empty bubble (and, on Redo, the
      // answer being replaced).
      if (m.isWizard && m.isPending) continue;
      final restored = _restoredIds.contains(m.id);
      rows.add(
        ProChatMessage.fromEntity(
          m,
          id: m.id,
          restored: restored,
          localPaths: _localPaths[m.id],
        ).copyWith(
          showActions: m.isWizard && m.id == lastWizardId && !m.isPending && !restored && m.options.isEmpty,
          optionsLoading: _optionsLoading.contains(m.id) || m.pendingOptions,
        ),
      );
    }
    rows.addAll(_failed);
    if (_inFlight case final pending?) rows.add(pending);
    final typing = _server.any((m) => m.isWizard && m.isPending) || _inFlight != null;
    emit(state.copyWith(
      messages: rows,
      isTyping: typing,
      failure: failure,
      errorCount: failure == null ? state.errorCount : state.errorCount + 1,
    ));
  }

  /// An options request that failed on the server reaches us through the listener; report it
  /// once, the same way a failed HTTP call is reported.
  Failure? _newOptionsFailure() {
    for (final message in _server) {
      final error = message.optionsError;
      if (error != null && _reportedOptionErrors.add(message.id)) return ServerFailure(error);
      if (error == null) _reportedOptionErrors.remove(message.id);
    }
    return null;
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
