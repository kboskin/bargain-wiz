import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:appwizard/features/conversation/domain/conversation_changes.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:appwizard/features/history/presentation/cubit/history_state.dart';

/// Bargains History: load / search / filter / delete / update status.
/// Reloads automatically when [ConversationChanges] fires (a deal was saved elsewhere).
class HistoryCubit extends Cubit<HistoryState> {
  /// [overrideLabels] maps a stored answer value to the labels its onboarding option
  /// configures, so search matches what the person saw; read at load time, since remote
  /// config can change under a running app.
  HistoryCubit(
    this._repository, {
    Listenable? changes,
    Map<String, String> Function()? overrideLabels,
  })  : _changes = changes ?? ConversationChanges.instance,
        _overrideLabels = overrideLabels ?? (() => const {}),
        super(const HistoryState()) {
    _changes.addListener(_onChanged);
  }

  final ConversationRepository _repository;
  final Listenable _changes;
  final Map<String, String> Function() _overrideLabels;

  Future<void> load() async {
    emit(state.copyWith(loadStatus: HistoryLoadStatus.loading, clearError: true));
    final result = await _repository.getConversations();
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(
        loadStatus: HistoryLoadStatus.failure,
        errorMessage: failure.message,
      )),
      (list) => emit(state.copyWith(
        loadStatus: HistoryLoadStatus.ready,
        conversations: sortNewestFirst(list),
        overrideLabels: _overrideLabels(),
      )),
    );
  }

  void search(String query) {
    if (query == state.query) return;
    emit(state.copyWith(query: query));
  }

  void setFilter(HistoryFilter filter) {
    if (filter == state.filter) return;
    emit(state.copyWith(filter: filter));
  }

  /// Optimistically removes the row, then deletes; restores it on failure.
  Future<bool> delete(String id) async {
    final before = state.conversations;
    emit(state.copyWith(
      conversations: before.where((c) => c.id != id).toList(),
      clearError: true,
    ));
    final result = await _repository.deleteConversation(id);
    if (isClosed) return result.isRight();
    return result.fold(
      (failure) {
        emit(state.copyWith(conversations: before, errorMessage: failure.message));
        return false;
      },
      (_) => true,
    );
  }

  /// Sets Open / Won / Lost (and optionally the final price) on a saved deal.
  Future<bool> updateStatus(
    String id,
    ConversationStatus status, {
    String? priceAfter,
  }) async {
    final result = await _repository.updateStatus(id, status, priceAfter: priceAfter);
    if (isClosed) return result.isRight();
    return result.fold(
      (failure) {
        emit(state.copyWith(errorMessage: failure.message));
        return false;
      },
      (updated) {
        emit(state.copyWith(
          conversations: [
            for (final c in state.conversations) c.id == id ? updated : c,
          ],
          clearError: true,
        ));
        return true;
      },
    );
  }

  static List<Conversation> sortNewestFirst(Iterable<Conversation> list) =>
      list.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  void _onChanged() {
    if (isClosed) return;
    load();
  }

  @override
  Future<void> close() {
    _changes.removeListener(_onChanged);
    return super.close();
  }
}
