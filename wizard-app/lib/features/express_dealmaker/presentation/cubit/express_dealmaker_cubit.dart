import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:appwizard/core/config/prefs_keys.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:appwizard/features/express_dealmaker/domain/repositories/express_dealmaker_repository.dart';
import 'package:appwizard/features/express_dealmaker/domain/utils/deal_title.dart';
import 'package:appwizard/features/express_dealmaker/presentation/cubit/express_dealmaker_state.dart';
import 'package:appwizard/features/express_dealmaker/presentation/pages/screenshot_upload_item.dart';

export 'package:appwizard/features/express_dealmaker/presentation/cubit/express_dealmaker_state.dart';

/// Context-derived inputs for [ExpressDealmakerCubit] (passed through get_it's
/// `registerFactoryParam`).
class ExpressDealmakerCubitParams {
  const ExpressDealmakerCubitParams({
    this.vibeId = '',
    this.locale = 'en',
    this.marketplace,
  });

  final String vibeId;
  final String locale;
  final String? marketplace;
}

/// Drives the Express Dealmaker flow: pick → uploading → ready / error,
/// Get More / tone changes, reopening from history and saving on back.
///
/// Context-derived values (vibe, locale, marketplace) are passed in by the page;
/// the cubit itself only depends on repositories so it can be unit-tested with fakes.
class ExpressDealmakerCubit extends Cubit<ExpressDealmakerState> {
  ExpressDealmakerCubit({
    required final ExpressDealmakerRepository repository,
    required final ConversationRepository conversationRepository,
    final SharedPreferences? prefs,
    final String vibeId = '',
    final String locale = 'en',
    final String? marketplace,
  })  : _repository = repository,
        _conversationRepository = conversationRepository,
        _prefs = prefs,
        _locale = locale,
        _marketplace = marketplace,
        super(ExpressDealmakerState(vibeId: vibeId));

  final ExpressDealmakerRepository _repository;
  final ConversationRepository _conversationRepository;
  final SharedPreferences? _prefs;
  final String _locale;
  final String? _marketplace;

  /// Conversation loaded from history (keeps id / createdAt / status on save).
  Conversation? _loaded;
  /// Paths whose upload is currently in flight (prevents duplicate uploads).
  final Set<String> _inFlight = {};

  // ── Entry ──────────────────────────────────────────────────────────────

  /// Entry point. Reopens [conversationId] when given, otherwise starts
  /// uploading [initialPaths] or shows the pick stage when empty.
  Future<void> start({
    final String? conversationId,
    final List<String> initialPaths = const [],
  }) async {
    if (conversationId != null) {
      await _loadConversation(conversationId);
      return;
    }
    if (initialPaths.isNotEmpty) {
      // Skip the pick stage entirely: land on "uploading" with the shots in place.
      final unique = <String>{};
      emit(state.copyWith(
        phase: ExpressPhase.uploading,
        screenshots: [
          for (final p in initialPaths)
            if (p.isNotEmpty && unique.add(p)) ScreenshotUploadItem(path: p),
        ],
      ));
      await startUpload();
      return;
    }
    emit(state.copyWith(phase: ExpressPhase.pick));
  }

  Future<void> _loadConversation(final String id) async {
    emit(state.copyWith(loadingConversation: true, conversationId: id));
    final result = await _conversationRepository.getConversations();
    if (isClosed) return;
    final conversation = result.fold<Conversation?>(
      (_) => null,
      (final list) => list.where((final c) => c.id == id).firstOrNull,
    );
    if (conversation == null) {
      emit(state.copyWith(loadingConversation: false, phase: ExpressPhase.pick));
      return;
    }
    _loaded = conversation;
    final lines = conversation.effectiveLines;
    // No lines and a recorded failure is a deal that broke, not an empty one: show the error
    // with Retry (which regenerates from the screenshots the server already has) instead of
    // dropping the user into a bare picker.
    final failed = lines.isEmpty && conversation.errorMessage != null;
    emit(state.copyWith(
      loadingConversation: false,
      phase: lines.isNotEmpty
          ? ExpressPhase.ready
          : failed
              ? ExpressPhase.error
              : ExpressPhase.pick,
      errorKind: failed ? ExpressErrorKind.reply : null,
      errorMessage: failed ? conversation.errorMessage : null,
      screenshots: conversation.screenshotPaths
          .map((final p) => ScreenshotUploadItem(path: p, status: ScreenshotUploadStatus.success))
          .toList(),
      lines: lines,
      seeing: conversation.seeing,
      keyword: conversation.keyword ?? '',
      vibeId: conversation.vibe ?? state.vibeId,
      requestId: lines.isNotEmpty ? 1 : 0,
      clearError: !failed,
    ));
  }

  // ── Selection ──────────────────────────────────────────────────────────

  /// Appends new screenshot paths (duplicates ignored). In the pick stage they
  /// wait for [startUpload]; in any later stage the upload starts right away and
  /// the reply is re-requested once every upload has finished.
  void addPaths(final List<String> paths) {
    final existing = state.paths.toSet();
    final fresh = paths.where((final p) => p.isNotEmpty && existing.add(p)).toList();
    if (fresh.isEmpty) return;
    // An express conversation takes no follow-up turns (the backend rejects `send`, and `redo`
    // carries no images), so screenshots added to one that already exists on the server would
    // be silently dropped. They start a new deal instead.
    if (state.conversationId != null) _loaded = null;
    emit(state.copyWith(
      screenshots: [...state.screenshots, ...fresh.map((final p) => ScreenshotUploadItem(path: p))],
      clearConversationId: state.conversationId != null,
    ));
    if (state.phase != ExpressPhase.pick) {
      unawaited(startUpload());
    }
  }

  /// Removes a screenshot before uploading (pick stage only).
  void removeAt(final int index) {
    if (state.phase != ExpressPhase.pick) return;
    if (index < 0 || index >= state.screenshots.length) return;
    final next = [...state.screenshots]..removeAt(index);
    emit(state.copyWith(screenshots: next));
  }

  void setKeyword(final String value) {
    if (value == state.keyword) return;
    emit(state.copyWith(keyword: value));
  }

  // ── Uploading ──────────────────────────────────────────────────────────

  /// Uploads every screenshot that has not succeeded yet, then auto-requests the
  /// reply when at least one upload succeeded (or shows the error stage).
  Future<void> startUpload() async {
    if (!state.hasScreenshots) return;
    final pending = state.screenshots
        .where((final s) => !s.isSuccess && !_inFlight.contains(s.path))
        .map((final s) => s.path)
        .toList();
    emit(state.copyWith(
      phase: ExpressPhase.uploading,
      clearError: true,
      screenshots: state.screenshots
          .map((final s) => s.isSuccess ? s : s.copyWith(status: ScreenshotUploadStatus.uploading))
          .toList(),
    ));
    if (pending.isEmpty) {
      if (_inFlight.isEmpty) await requestReply();
      return;
    }
    await Future.wait(pending.map(_upload));
  }

  /// Re-uploads a single failed screenshot (per-card Retry chip).
  Future<void> retryUpload(final int index) async {
    if (index < 0 || index >= state.screenshots.length) return;
    final item = state.screenshots[index];
    if (!item.isFailed || _inFlight.contains(item.path)) return;
    _setItem(item.path, item.copyWith(status: ScreenshotUploadStatus.uploading));
    if (state.phase == ExpressPhase.error) {
      emit(state.copyWith(phase: ExpressPhase.uploading, clearError: true));
    }
    await _upload(item.path);
  }

  Future<void> _upload(final String path) async {
    _inFlight.add(path);
    final result = await _repository.uploadScreenshot(path);
    _inFlight.remove(path);
    if (isClosed) return;
    final current = state.screenshots.where((final s) => s.path == path).firstOrNull;
    if (current == null) return; // removed meanwhile
    result.fold(
      (_) => _setItem(path, current.copyWith(status: ScreenshotUploadStatus.failed)),
      (final r) => _setItem(
        path,
        current.copyWith(status: ScreenshotUploadStatus.success, uploadedId: r.id),
      ),
    );
    await _afterUploadSettled();
  }

  void _setItem(final String path, final ScreenshotUploadItem item) {
    emit(state.copyWith(
      screenshots: state.screenshots.map((final s) => s.path == path ? item : s).toList(),
    ));
  }

  /// Called after each upload completes: once everything settled while in the
  /// uploading stage, either auto-request the reply or show the error stage.
  Future<void> _afterUploadSettled() async {
    if (state.phase != ExpressPhase.uploading || state.replyLoading) return;
    if (!state.allDone || _inFlight.isNotEmpty) return;
    if (state.uploadedIds.isEmpty) {
      emit(state.copyWith(phase: ExpressPhase.error, errorKind: ExpressErrorKind.upload));
      return;
    }
    await requestReply();
  }

  // ── Reply ──────────────────────────────────────────────────────────────

  /// Requests (or re-requests, "Get More") lines for the uploaded screenshots
  /// with the current keyword and tone.
  Future<void> requestReply() async {
    final ids = state.uploadedIds;
    // A redo needs no ids: the screenshots are already on the server.
    if (state.replyLoading || (ids.isEmpty && state.conversationId == null)) return;
    emit(state.copyWith(replyLoading: true, clearError: true));
    final keyword = state.keyword.trim();
    final result = await _repository.getDealReply(
      uploadedIds: ids,
      keyword: keyword.isEmpty ? null : keyword,
      locale: _locale,
      vibe: state.vibeId,
      conversationId: state.conversationId,
    );
    if (isClosed) return;
    result.fold(
      (final failure) => emit(state.copyWith(
        phase: ExpressPhase.error,
        replyLoading: false,
        errorKind: ExpressErrorKind.reply,
        errorMessage: failure.message,
      )),
      (final reply) {
        emit(state.copyWith(
          phase: ExpressPhase.ready,
          replyLoading: false,
          lines: reply.lines,
          seeing: reply.seeing,
          conversationId: reply.conversationId ?? state.conversationId,
          requestId: state.requestId + 1,
          clearError: true,
        ));
        unawaited(_markExpressUsed());
      },
    );
  }

  /// Switches the tone. Persisting the vibe on the user profile is done by the
  /// page; here we only re-request lines when results are already showing.
  Future<void> changeVibe(final String vibeId) async {
    if (vibeId == state.vibeId) return;
    emit(state.copyWith(vibeId: vibeId));
    final shouldRefetch = state.phase == ExpressPhase.ready ||
        (state.phase == ExpressPhase.error && state.errorKind == ExpressErrorKind.reply);
    if (shouldRefetch) await requestReply();
  }

  /// Error-stage Retry: re-uploads what failed or re-requests the reply.
  Future<void> retry() async {
    switch (state.errorKind) {
      case ExpressErrorKind.upload:
        await startUpload();
      case ExpressErrorKind.reply:
        await requestReply();
      case ExpressErrorKind.load:
      case null:
        if (state.anyFailed || state.anyUploading) {
          await startUpload();
        } else if (state.uploadedIds.isNotEmpty) {
          await requestReply();
        } else {
          emit(state.copyWith(phase: ExpressPhase.pick, clearError: true));
        }
    }
  }

  Future<void> _markExpressUsed() async {
    final prefs = _prefs;
    if (prefs == null) return;
    if (prefs.getBool(PrefsKeys.expressUsed) ?? false) return;
    await prefs.setBool(PrefsKeys.expressUsed, true);
  }

  // ── Persistence ────────────────────────────────────────────────────────

  /// Persists history metadata (title, tone, marketplace) for the backend conversation
  /// (called on back). The deal itself already lives on the server; nothing to save before
  /// the backend has created it.
  Future<bool> saveConversation() async {
    if (!state.isSaveable || state.conversationId == null) return false;
    final conversation = buildConversation();
    final result = await _conversationRepository.saveConversation(conversation);
    return result.isRight();
  }

  /// The [Conversation] that [saveConversation] would persist.
  Conversation buildConversation() {
    final now = DateTime.now();
    final keyword = state.keyword.trim();
    final base = _loaded ??
        Conversation(
          id: state.conversationId ?? now.millisecondsSinceEpoch.toString(),
          type: ConversationType.express,
          createdAt: now,
        );
    return base.copyWith(
      type: ConversationType.express,
      screenshotPaths: state.paths,
      replyLines: state.lines,
      keyword: keyword.isEmpty ? null : keyword,
      title: DealTitle.fromSeeing(state.seeing ?? base.seeing),
      marketplace: _marketplace ?? base.marketplace,
      seeing: state.seeing ?? base.seeing,
      vibe: state.vibeId,
    );
  }
}
