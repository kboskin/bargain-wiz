import 'package:equatable/equatable.dart';

import 'package:appwizard/core/config/wiz_catalog.dart';
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
  });

  final HistoryLoadStatus loadStatus;
  /// Every saved conversation, newest first.
  final List<Conversation> conversations;
  final String query;
  final HistoryFilter filter;
  final String? errorMessage;

  bool get isLoading =>
      loadStatus == HistoryLoadStatus.loading || loadStatus == HistoryLoadStatus.initial;
  bool get hasAny => conversations.isNotEmpty;
  bool get isFiltering => query.trim().isNotEmpty || filter != HistoryFilter.all;

  /// Rows after applying [filter] and [query].
  List<Conversation> get visible => apply(conversations, query: query, filter: filter);

  /// Pure filter: status chip + case-insensitive search on title and marketplace.
  static List<Conversation> apply(
    Iterable<Conversation> source, {
    String query = '',
    HistoryFilter filter = HistoryFilter.all,
  }) {
    final status = filter.status;
    final q = query.trim().toLowerCase();
    return source.where((c) {
      if (status != null && c.status != status) return false;
      if (q.isEmpty) return true;
      final haystack = [
        ConversationTitleHelper.titleOf(c),
        WizCatalog.marketplaceLabel(c.marketplace, fallback: ''),
        c.marketplace ?? '',
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
  }) =>
      HistoryState(
        loadStatus: loadStatus ?? this.loadStatus,
        conversations: conversations ?? this.conversations,
        query: query ?? this.query,
        filter: filter ?? this.filter,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );

  @override
  List<Object?> get props => [loadStatus, conversations, query, filter, errorMessage];
}
