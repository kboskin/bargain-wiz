import 'package:dartz/dartz.dart';

import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/features/lines_that_land/domain/entities/lines_that_land_category.dart';
import 'package:appwizard/features/lines_that_land/domain/entities/lines_that_land_feed.dart';

/// Repository for "Lines that land" categories (each with a daily tip).
///
/// Content comes only from the backend endpoint the `lines_that_land` Cloud Function and is
/// cached on device for the `refresh_interval_hours` the endpoint declares. Offline with
/// no cache yields a [NetworkFailure]; the app reads no Remote Config key for this.
/// See LINES_THAT_LAND.md.
abstract class LinesThatLandRepository {
  /// Current feed: categories plus freshness metadata (when the content last changed,
  /// how often it refreshes, where this copy came from).
  Future<Either<Failure, LinesThatLandFeed>> getFeed();

  /// Returns categories with one daily tip each (rotated by day index).
  /// Returns empty list when no categories are configured.
  Future<Either<Failure, List<LinesThatLandCategory>>> getDailyCategories();
}
