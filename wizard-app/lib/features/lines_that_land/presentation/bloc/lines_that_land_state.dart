import 'package:appwizard/features/lines_that_land/domain/entities/lines_that_land_category.dart';
import 'package:appwizard/features/lines_that_land/domain/entities/lines_that_land_feed.dart';
import 'package:appwizard/features/shared/presentation/bloc/base_bloc.dart';

/// Lines that land states.
abstract class LinesThatLandState extends BaseState {
  const LinesThatLandState();
}

/// Nothing cached yet and no refresh started.
class LinesThatLandInitial extends LinesThatLandState {
  const LinesThatLandInitial();
}

/// First fetch running with nothing to show meanwhile.
class LinesThatLandLoading extends LinesThatLandState {
  const LinesThatLandLoading();
}

class LinesThatLandLoaded extends LinesThatLandState {
  const LinesThatLandLoaded(
    this.categories, {
    this.updatedAt,
    this.refreshInterval,
    this.source,
    this.isStale = false,
    this.isRefreshing = false,
    this.refreshError,
  });

  factory LinesThatLandLoaded.fromFeed(LinesThatLandFeed feed) => LinesThatLandLoaded(
        feed.categories,
        updatedAt: feed.updatedAt,
        refreshInterval: feed.refreshInterval,
        source: feed.source,
        isStale: feed.isStale,
      );

  final List<LinesThatLandCategory> categories;

  /// When the content last changed on the server (null for the bundled fallback).
  final DateTime? updatedAt;

  /// How often the content is refreshed, as declared by the endpoint.
  final Duration? refreshInterval;
  final LinesFeedSource? source;

  /// Cached copy older than [refreshInterval]; a background refresh is due or running.
  final bool isStale;

  /// A refresh is in flight; the content stays on screen.
  final bool isRefreshing;

  /// The last refresh failed (content kept); surfaced once as a toast.
  final String? refreshError;

  LinesThatLandLoaded copyWith({bool? isRefreshing, String? refreshError, bool clearError = false}) =>
      LinesThatLandLoaded(
        categories,
        updatedAt: updatedAt,
        refreshInterval: refreshInterval,
        source: source,
        isStale: isStale,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        refreshError: clearError ? null : (refreshError ?? this.refreshError),
      );

  @override
  List<Object?> get props => [categories, updatedAt, refreshInterval, source, isStale, isRefreshing, refreshError];
}

/// Nothing to show: no cache and the fetch failed.
class LinesThatLandError extends LinesThatLandState {
  const LinesThatLandError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
