import 'package:dartz/dartz.dart';

import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/features/lines_that_land/domain/entities/lines_that_land_category.dart';

/// Repository for "Lines that land" categories (each with a daily tip).
/// Data is rotated on a daily basis from the backend (e.g. Remote Config).
abstract class LinesThatLandRepository {
  /// Returns categories with one daily tip each (rotated by day index).
  /// Returns empty list when no categories are configured.
  Future<Either<Failure, List<LinesThatLandCategory>>> getDailyCategories();
}
