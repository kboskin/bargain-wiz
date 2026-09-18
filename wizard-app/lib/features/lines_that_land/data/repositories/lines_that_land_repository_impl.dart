import 'package:dartz/dartz.dart';

import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/lines_that_land/data/datasources/lines_that_land_api_datasource.dart';
import 'package:appwizard/features/lines_that_land/data/datasources/lines_that_land_local_cache.dart';
import 'package:appwizard/features/lines_that_land/data/mappers/lines_that_land_mapper.dart';
import 'package:appwizard/features/lines_that_land/data/models/lines_that_land_response.dart';
import 'package:appwizard/features/lines_that_land/domain/entities/lines_that_land_category.dart';
import 'package:appwizard/features/lines_that_land/domain/entities/lines_that_land_feed.dart';
import 'package:appwizard/features/lines_that_land/domain/repositories/lines_that_land_repository.dart';

/// Function-backed "Lines that land" with an on-device cache (see LINES_THAT_LAND.md).
///
/// [cached] is what the tab renders at once (no request, works offline); [refresh] talks to
/// the `lines_that_land` Cloud Function and runs in the background when the copy is older
/// than the function's `refresh_interval_hours`, or when the user pulls to refresh.
/// No Remote Config key is read; the function owns the content and its fallback.
class LinesThatLandRepositoryImpl implements LinesThatLandRepository {
  LinesThatLandRepositoryImpl({
    required LinesThatLandApiDataSource api,
    required LinesThatLandLocalCache cache,
    required LinesThatLandMapper mapper,
    required AppLogger logger,
    DateTime Function()? now,
  })  : _api = api,
        _cache = cache,
        _mapper = mapper,
        _logger = logger,
        _now = now ?? DateTime.now;

  /// User-facing message when there is neither network nor a cached copy.
  static const String offlineMessage = "Couldn't load lines. Check your connection and try again.";

  final LinesThatLandApiDataSource _api;
  final LinesThatLandLocalCache _cache;
  final LinesThatLandMapper _mapper;
  final AppLogger _logger;
  final DateTime Function() _now;

  /// Day index origin for the rotating `dailyTip`.
  static final DateTime _epoch = DateTime.utc(2025, 1, 1);

  @override
  LinesThatLandFeed? cached() {
    final now = _now().toUtc();
    final cached = _cache.read();
    if (cached == null) return null;
    return _toFeed(cached.response, now, LinesFeedSource.cache, isStale: !cached.isFresh(now));
  }

  @override
  Future<Either<Failure, LinesThatLandFeed>> refresh() async {
    final now = _now().toUtc();
    try {
      final fresh = await _api.fetchFeed();
      await _cache.write(fresh, now);
      return Right(_toFeed(fresh, now, LinesFeedSource.network));
    } on Object catch (e, stackTrace) {
      _logger.e('Lines that land function unavailable', e, stackTrace);
      return const Left(NetworkFailure(offlineMessage));
    }
  }

  @override
  Future<Either<Failure, LinesThatLandFeed>> getFeed() async {
    final local = cached();
    if (local != null && !local.isStale) return Right(local);
    final result = await refresh();
    if (local == null) return result;
    return result.fold((_) => Right(local), Right.new); // a stale copy beats an offline failure
  }

  @override
  Future<Either<Failure, List<LinesThatLandCategory>>> getDailyCategories() async =>
      (await getFeed()).map((feed) => feed.categories);

  LinesThatLandFeed _toFeed(
    LinesThatLandResponse response,
    DateTime now,
    LinesFeedSource source, {
    bool isStale = false,
  }) =>
      LinesThatLandFeed(
        categories: _mapper.toCategoryEntities(response.categories, now.difference(_epoch).inDays),
        locales: response.locales,
        updatedAt: response.updatedAt,
        refreshInterval: response.refreshInterval,
        source: source,
        isStale: isStale,
      );
}
