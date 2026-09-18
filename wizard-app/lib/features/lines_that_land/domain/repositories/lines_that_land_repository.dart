import 'package:dartz/dartz.dart';

import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/features/lines_that_land/domain/entities/lines_that_land_category.dart';
import 'package:appwizard/features/lines_that_land/domain/entities/lines_that_land_feed.dart';

/// Repository for "Lines that land" categories (each with a daily tip).
///
/// Content comes only from the `lines_that_land` Cloud Function and is cached on device for
/// the `refresh_interval_hours` the endpoint declares. The app reads no Remote Config key for
/// this. See LINES_THAT_LAND.md.
abstract class LinesThatLandRepository {
  /// The on-device copy, instantly and without any network call; null before the first
  /// successful fetch. [LinesThatLandFeed.isStale] says whether a refresh is due.
  LinesThatLandFeed? cached();

  /// Calls the endpoint and replaces the on-device copy. Callers keep showing [cached] while
  /// this runs and apply the result when it lands.
  Future<Either<Failure, LinesThatLandFeed>> refresh();

  /// Convenience: [cached] when fresh, else [refresh]; a stale copy beats an offline failure.
  Future<Either<Failure, LinesThatLandFeed>> getFeed();

  /// Returns categories with one daily tip each (rotated by day index).
  /// Returns empty list when no categories are configured.
  Future<Either<Failure, List<LinesThatLandCategory>>> getDailyCategories();
}
