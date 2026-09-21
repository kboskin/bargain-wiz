import 'package:equatable/equatable.dart';

import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/conversation/domain/helpers/conversation_title_helper.dart';

/// Filter chips of the Bargains History screen: All · Open · Won · Lost.
enum HistoryFilter {
  all,
  open,
  won,
  lost;

  /// Status matched by this filter (`null` for [all]).
  ConversationStatus? get status {
    switch (this) {
      case HistoryFilter.all:
        return null;
      case HistoryFilter.open:
        return ConversationStatus.open;
      case HistoryFilter.won:
        return ConversationStatus.won;
      case HistoryFilter.lost:
        return ConversationStatus.lost;
    }
  }
}

enum HistoryLoadStatus { initial, loading, ready, failure }

class HistoryState extends Equatable {
  const HistoryState({
    this.loadStatus = HistoryLoadStatus.initial,
    this.conversations = const [],
    this.query = '',
    this.filter = HistoryFilter.all,
    this.errorMessage,
    this.overrideLabels = const {},
  });

  final HistoryLoadStatus loadStatus;
  /// Every saved conversation, newest first.
  final List<Conversation> conversations;
  final String query;
  final HistoryFilter filter;
  final String? errorMessage;

  /// Stored marketplace value → the label its onboarding option configures, for search.
  final Map<String, String> overrideLabels;

  bool get isLoading =>
      loadStatus == HistoryLoadStatus.loading || loadStatus == HistoryLoadStatus.initial;
  bool get hasAny => conversations.isNotEmpty;
  bool get isFiltering => query.trim().isNotEmpty || filter != HistoryFilter.all;

  /// Rows after applying [filter] and [query].
  List<Conversation> get visible =>
      apply(conversations, query: query, filter: filter, overrideLabels: overrideLabels);

  /// Pure filter: status chip + case-insensitive search on title and marketplace.
  /// [overrideLabels] maps a stored answer value to the label its onboarding option
  /// configures, so "Facebook Marketplace" finds a deal stored as `facebook`.
  static List<Conversation> apply(
    Iterable<Conversation> source, {
    String query = '',
    HistoryFilter filter = HistoryFilter.all,
    Map<String, String> overrideLabels = const {},
  }) {
    final status = filter.status;
    final q = query.trim().toLowerCase();
    return source.where((c) {
      if (status != null && c.status != status) return false;
      if (q.isEmpty) return true;
      final values = [for (final v in (c.overrides ?? const {}).values) '$v'];
      final haystack = [
        ConversationTitleHelper.titleOf(c),
        for (final value in values) ...[overrideLabels[value] ?? '', value],
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  HistoryState copyWith({
    HistoryLoadStatus? loadStatus,
    List<Conversation>? conversations,
    String? query,
    HistoryFilter? filter,
    String? errorMessage,
    bool clearError = false,
    Map<String, String>? overrideLabels,
  }) =>
      HistoryState(
        loadStatus: loadStatus ?? this.loadStatus,
        conversations: conversations ?? this.conversations,
        query: query ?? this.query,
        filter: filter ?? this.filter,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        overrideLabels: overrideLabels ?? this.overrideLabels,
      );

  @override
  List<Object?> get props =>
      [loadStatus, conversations, query, filter, errorMessage, overrideLabels];
}
