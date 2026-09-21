import 'dart:async';

import 'package:dartz/dartz.dart';

import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/core/network/cloud_functions_client.dart';
import 'package:appwizard/core/services/auth_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/conversation/data/datasources/conversations_api.dart';
import 'package:appwizard/features/conversation/data/datasources/conversations_stream.dart';
import 'package:appwizard/features/conversation/data/models/conversation_api_models.dart';
import 'package:appwizard/features/conversation/domain/conversation_changes.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/conversation/domain/repositories/conversation_repository.dart';

/// Conversations owned by the backend: the list comes from a Firestore listener on the
/// current uid (anonymous or not), writes go through the `conversations` function.
///
/// Every snapshot bumps [ConversationChanges], so screens that already reload on it (Home,
/// History) stay live. [getConversations] serves the latest snapshot and waits for the first
/// one (bounded by [firstSnapshotTimeout]) so a cold start is not empty.
class ConversationRepositoryImpl implements ConversationRepository {
  ConversationRepositoryImpl({
    required ConversationsApi api,
    required ConversationsStream stream,
    required AuthService auth,
    required AppLogger logger,
    ConversationChanges? changes,
    this.firstSnapshotTimeout = const Duration(seconds: 8),
  })  : _api = api,
        _stream = stream,
        _auth = auth,
        _logger = logger,
        _changes = changes ?? ConversationChanges.instance;

  final ConversationsApi _api;
  final ConversationsStream _stream;
  final AuthService _auth;
  final AppLogger _logger;
  final ConversationChanges _changes;
  final Duration firstSnapshotTimeout;

  List<Conversation> _cache = const [];
  String? _uid;
  StreamSubscription<List<Conversation>>? _subscription;
  StreamSubscription<String?>? _uidSubscription;
  Completer<void>? _firstSnapshot;

  /// Latest snapshot (empty before the first one).
  List<Conversation> get cached => List.unmodifiable(_cache);

  @override
  Future<Either<Failure, List<Conversation>>> getConversations() async {
    try {
      await _ensureListening();
      final first = _firstSnapshot;
      if (first != null && !first.isCompleted) {
        await first.future.timeout(firstSnapshotTimeout);
      }
      return Right(List.of(_cache));
    } on TimeoutException {
      _logger.w('Conversations: first snapshot is slow; serving what we have');
      return Right(List.of(_cache));
    } on Object catch (e, stackTrace) {
      _logger.e('Error listening to conversations', e, stackTrace);
      return Left(ServerFailure(e.toString()));
    }
  }

  /// History metadata only (status, prices, title, the deal's overrides): the messages already
  /// live on the server.
  @override
  Future<Either<Failure, void>> saveConversation(Conversation conversation) async {
    try {
      await _api.patch(
        conversation.id,
        ConversationPatchRequest(
          title: conversation.title,
          status: conversation.status.name,
          priceBefore: conversation.priceBefore,
          priceAfter: conversation.priceAfter,
          overrides: conversation.overrides,
        ),
      );
      _cache = [for (final c in _cache) c.id == conversation.id ? conversation : c];
      _changes.bump();
      return const Right(null);
    } on Object catch (e, stackTrace) {
      _logger.e('Error saving conversation', e, stackTrace);
      return Left(_failure(e));
    }
  }

  /// Archives on the backend; the row disappears at once and the listener confirms.
  @override
  Future<Either<Failure, void>> deleteConversation(String id) async {
    final before = _cache;
    _cache = before.where((c) => c.id != id).toList();
    _changes.bump();
    try {
      await _api.archive(id);
      return const Right(null);
    } on Object catch (e, stackTrace) {
      _logger.e('Error deleting conversation', e, stackTrace);
      if (e is! CloudFunctionException || e.httpStatus != 404) {
        _cache = before;
        _changes.bump();
      }
      return Left(_failure(e));
    }
  }


  Future<void> _ensureListening() async {
    _uidSubscription ??= _auth.uidChanges.listen((uid) {
      if (uid != _uid) _listenAs(uid);
    });
    final uid = await _auth.ensureUid();
    // Without a uid there is nothing to listen to; do not notify anyone, or every listener
    // that reloads on change would come straight back here (and re-attempt the sign-in).
    if (uid == null) {
      if (_uid != null) _listenAs(null);
      return;
    }
    if (uid != _uid || _subscription == null) _listenAs(uid);
  }

  void _listenAs(String? uid) {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _uid = uid;
    final hadRows = _cache.isNotEmpty;
    _cache = const [];
    final first = _firstSnapshot = Completer<void>();
    if (uid == null) {
      first.complete();
      if (hadRows) _changes.bump();
      return;
    }
    _subscription = _stream.watchConversations(uid).listen(
      (list) {
        _cache = list;
        if (!first.isCompleted) first.complete();
        _changes.bump();
      },
      onError: (Object e, StackTrace stackTrace) {
        _logger.e('Conversations listener failed', e, stackTrace);
        if (!first.isCompleted) first.completeError(e);
      },
    );
  }

  Failure _failure(Object e) {
    if (e is CloudFunctionException) {
      return e.httpStatus == 404 ? CacheFailure(e.message) : ServerFailure(e.message);
    }
    return ServerFailure(e.toString());
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _uidSubscription?.cancel();
  }
}
