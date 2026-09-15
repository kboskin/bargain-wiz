import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/lines_that_land/data/datasources/lines_that_land_api_datasource.dart';
import 'package:appwizard/features/lines_that_land/data/datasources/lines_that_land_local_cache.dart';
import 'package:appwizard/features/lines_that_land/data/mappers/lines_that_land_mapper.dart';
import 'package:appwizard/features/lines_that_land/data/models/lines_that_land_response.dart';
import 'package:appwizard/features/lines_that_land/data/repositories/lines_that_land_repository_impl.dart';
import 'package:appwizard/features/lines_that_land/domain/entities/lines_that_land_feed.dart';
import 'package:flutter_test/flutter_test.dart';

class _SilentLogger implements AppLogger {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeApi implements LinesThatLandApiDataSource {
  _FakeApi(this._handler);

  final Future<LinesThatLandResponse> Function() _handler;
  int calls = 0;

  @override
  Future<LinesThatLandResponse> fetchFeed() {
    calls++;
    return _handler();
  }
}

class _MemoryCache implements LinesThatLandLocalCache {
  CachedLinesFeed? stored;

  @override
  CachedLinesFeed? read() => stored;

  @override
  Future<void> write(LinesThatLandResponse response, DateTime fetchedAt) async {
    stored = CachedLinesFeed(response, fetchedAt);
  }
}

void main() {
  final now = DateTime.utc(2026, 9, 12, 12);
  final serverUpdatedAt = DateTime.utc(2026, 9, 12, 10);

  LinesThatLandResponse payload({String tip = 'Fresh line', int hours = 24}) => LinesThatLandResponse.fromJson({
        'categories': [
          {'id': 'opening', 'name': {'en': 'Opening lines', 'es': 'Frases de apertura'}, 'tips': [tip]},
        ],
        'locales': ['en', 'es'],
        'updated_at': serverUpdatedAt.toIso8601String(),
        'refresh_interval_hours': hours,
        'source': 'remote_config',
      });

  LinesThatLandRepositoryImpl repo(_FakeApi api, _MemoryCache cache) => LinesThatLandRepositoryImpl(
        api: api,
        cache: cache,
        mapper: LinesThatLandMapper(),
        logger: _SilentLogger(),
        now: () => now,
      );

  Future<LinesThatLandFeed> feedOf(LinesThatLandRepositoryImpl r) async =>
      (await r.getFeed()).fold((f) => throw StateError(f.message), (feed) => feed);

  Object? firstTip(LinesThatLandFeed feed) => feed.categories.single.tips.single.text.toJson();

  group('LinesThatLandRepositoryImpl.getFeed', () {
    test('serves a fresh cache without calling the function', () async {
      final cache = _MemoryCache()
        ..stored = CachedLinesFeed(payload(tip: 'Cached line'), now.subtract(const Duration(hours: 1)));
      final api = _FakeApi(() async => payload());

      final feed = await feedOf(repo(api, cache));

      expect(api.calls, 0);
      expect(feed.source, LinesFeedSource.cache);
      expect(firstTip(feed), 'Cached line');
    });

    test('refetches once the cache is older than the declared interval and stores the response',
        () async {
      final cache = _MemoryCache()
        ..stored = CachedLinesFeed(payload(tip: 'Cached line'), now.subtract(const Duration(hours: 25)));
      final api = _FakeApi(() async => payload());

      final feed = await feedOf(repo(api, cache));

      expect(api.calls, 1);
      expect(feed.source, LinesFeedSource.network);
      expect(firstTip(feed), 'Fresh line');
      expect(feed.locales, ['en', 'es']);
      expect(feed.updatedAt, serverUpdatedAt);
      expect(feed.refreshInterval, const Duration(hours: 24));
      expect(cache.stored!.fetchedAt, now);
      expect(cache.stored!.response.categories.single.tips.single.toJson(), 'Fresh line');
    });

    test('honours a shorter interval declared by the function', () async {
      final cache = _MemoryCache()
        ..stored = CachedLinesFeed(payload(tip: 'Cached line', hours: 6), now.subtract(const Duration(hours: 7)));
      final api = _FakeApi(() async => payload(hours: 6));

      await feedOf(repo(api, cache));

      expect(api.calls, 1);
    });

    test('keeps the stale cache when the function fails', () async {
      final cache = _MemoryCache()
        ..stored = CachedLinesFeed(payload(tip: 'Cached line'), now.subtract(const Duration(days: 3)));
      final api = _FakeApi(() async => throw Exception('offline'));

      final feed = await feedOf(repo(api, cache));

      expect(feed.source, LinesFeedSource.cache);
      expect(firstTip(feed), 'Cached line');
    });

    test('returns a NetworkFailure with a friendly message when there is no cache and no network', () async {
      final api = _FakeApi(() async => throw Exception('offline'));

      final result = await repo(api, _MemoryCache()).getFeed();

      expect(result.isLeft(), isTrue);
      final failure = result.fold((f) => f, (_) => null);
      expect(failure, isA<NetworkFailure>());
      expect(failure!.message, LinesThatLandRepositoryImpl.offlineMessage);
    });

    test('getDailyCategories exposes the feed categories', () async {
      final api = _FakeApi(() async => payload());
      final result = await repo(api, _MemoryCache()).getDailyCategories();
      expect(result.fold((_) => -1, (list) => list.length), 1);
    });
  });

  test('CachedLinesFeed.isFresh uses the payload interval', () {
    final cached = CachedLinesFeed(payload(hours: 6), now.subtract(const Duration(hours: 5)));
    expect(cached.isFresh(now), isTrue);
    expect(cached.isFresh(now.add(const Duration(hours: 2))), isFalse);
  });
}
