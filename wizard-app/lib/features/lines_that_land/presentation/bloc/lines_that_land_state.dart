import 'package:appwizard/features/lines_that_land/domain/entities/lines_that_land_category.dart';
import 'package:appwizard/features/lines_that_land/domain/entities/lines_that_land_feed.dart';
import 'package:appwizard/features/shared/presentation/bloc/base_bloc.dart';

/// Lines that land states.
abstract class LinesThatLandState extends BaseState {
  const LinesThatLandState();
}

class LinesThatLandInitial extends LinesThatLandState {
  const LinesThatLandInitial();
}

class LinesThatLandLoading extends LinesThatLandState {
  const LinesThatLandLoading();
}

class LinesThatLandLoaded extends LinesThatLandState {
  const LinesThatLandLoaded(
    this.categories, {
    this.updatedAt,
    this.refreshInterval,
    this.source,
  });

  factory LinesThatLandLoaded.fromFeed(LinesThatLandFeed feed) => LinesThatLandLoaded(
        feed.categories,
        updatedAt: feed.updatedAt,
        refreshInterval: feed.refreshInterval,
        source: feed.source,
      );

  final List<LinesThatLandCategory> categories;

  /// When the content last changed on the server (null for the bundled fallback).
  final DateTime? updatedAt;

  /// How often the content is refreshed, as declared by the endpoint.
  final Duration? refreshInterval;
  final LinesFeedSource? source;

  @override
  List<Object?> get props => [categories, updatedAt, refreshInterval, source];
}

class LinesThatLandError extends LinesThatLandState {
  const LinesThatLandError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
