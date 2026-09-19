import 'package:equatable/equatable.dart';

import 'package:appwizard/features/conversation/domain/entities/deal_line.dart';
import 'package:appwizard/features/express_dealmaker/presentation/pages/screenshot_upload_item.dart';

/// Stage of the Express Dealmaker flow (mirror of the prototype's `exPhase`).
enum ExpressPhase { pick, uploading, ready, error }

/// What failed when [ExpressPhase.error] is shown; drives what "Retry" does.
enum ExpressErrorKind { upload, reply, load }

class ExpressDealmakerState extends Equatable {
  const ExpressDealmakerState({
    required this.vibeId,
    this.phase = ExpressPhase.pick,
    this.screenshots = const [],
    this.lines = const [],
    this.seeing,
    this.keyword = '',
    this.replyLoading = false,
    this.conversationId,
    this.requestId = 0,
    this.errorKind,
    this.errorMessage,
    this.loadingConversation = false,
  });

  final ExpressPhase phase;
  final List<ScreenshotUploadItem> screenshots;
  final List<DealLine> lines;
  /// What the wizard saw in the screenshots (results strip).
  final String? seeing;
  final String keyword;
  /// Negotiation vibe id used for the current/next request.
  final String vibeId;
  /// True while a reply request is in flight (initial read, Get More, tone change).
  final bool replyLoading;
  /// Set when reopening a saved conversation (kept on save).
  final String? conversationId;
  /// Increments on every successful reply; used to replay card entrance animations.
  final int requestId;
  final ExpressErrorKind? errorKind;
  /// What the backend said went wrong (a rate limit names the wait); null uses the
  /// configured copy.
  final String? errorMessage;
  /// True while restoring a conversation from history.
  final bool loadingConversation;

  bool get hasScreenshots => screenshots.isNotEmpty;
  bool get anyUploading => screenshots.any((final s) => s.isUploading);
  bool get anyFailed => screenshots.any((final s) => s.isFailed);
  bool get allDone => screenshots.isNotEmpty && !anyUploading;
  List<ScreenshotUploadItem> get uploaded => screenshots.where((final s) => s.isSuccess).toList();
  List<String> get uploadedIds => uploaded.map((final s) => s.effectiveId).toList();
  List<String> get paths => screenshots.map((final s) => s.path).toList();
  /// Something worth persisting on back (results reached or an existing conversation).
  bool get isSaveable => lines.isNotEmpty || conversationId != null;

  ExpressDealmakerState copyWith({
    final ExpressPhase? phase,
    final List<ScreenshotUploadItem>? screenshots,
    final List<DealLine>? lines,
    final String? seeing,
    final bool clearSeeing = false,
    final String? keyword,
    final String? vibeId,
    final bool? replyLoading,
    final String? conversationId,
    final bool clearConversationId = false,
    final int? requestId,
    final ExpressErrorKind? errorKind,
    final String? errorMessage,
    final bool clearError = false,
    final bool? loadingConversation,
  }) =>
      ExpressDealmakerState(
        phase: phase ?? this.phase,
        screenshots: screenshots ?? this.screenshots,
        lines: lines ?? this.lines,
        seeing: clearSeeing ? null : (seeing ?? this.seeing),
        keyword: keyword ?? this.keyword,
        vibeId: vibeId ?? this.vibeId,
        replyLoading: replyLoading ?? this.replyLoading,
        conversationId: clearConversationId ? null : (conversationId ?? this.conversationId),
        requestId: requestId ?? this.requestId,
        errorKind: clearError ? null : (errorKind ?? this.errorKind),
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        loadingConversation: loadingConversation ?? this.loadingConversation,
      );

  @override
  List<Object?> get props => [
        phase,
        screenshots,
        lines,
        seeing,
        keyword,
        vibeId,
        replyLoading,
        conversationId,
        requestId,
        errorKind,
        errorMessage,
        loadingConversation,
      ];
}
