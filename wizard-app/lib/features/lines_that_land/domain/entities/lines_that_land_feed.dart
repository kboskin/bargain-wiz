import 'package:equatable/equatable.dart';

import 'package:appwizard/features/lines_that_land/domain/entities/lines_that_land_category.dart';

/// Where a [LinesThatLandFeed] copy came from.
enum LinesFeedSource {
  /// Fresh from the `lines_that_land` Cloud Function.
  network,

  /// On-device cache of an earlier endpoint response (fresh, or stale when offline).
  cache,
}

/// "Lines that land" content plus freshness metadata.
///
/// [updatedAt] is when the content last changed on the server; [refreshInterval] is the
/// cadence the endpoint declares (`refresh_interval_hours`), used both for the on-device
/// cache TTL and the "new lines every …" caption.
class LinesThatLandFeed extends Equatable {
  const LinesThatLandFeed({
    required this.categories,
    required this.refreshInterval,
    required this.source,
    this.locales = const [],
    this.updatedAt,
  });

  final List<LinesThatLandCategory> categories;

  /// Language codes present anywhere in the content.
  final List<String> locales;
  final DateTime? updatedAt;
  final Duration refreshInterval;
  final LinesFeedSource source;

  @override
  List<Object?> get props => [categories, locales, updatedAt, refreshInterval, source];
}
