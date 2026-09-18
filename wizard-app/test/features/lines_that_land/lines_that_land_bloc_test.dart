import 'dart:async';

import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/features/lines_that_land/domain/entities/lines_that_land_category.dart';
import 'package:appwizard/features/lines_that_land/domain/entities/lines_that_land_feed.dart';
import 'package:appwizard/features/lines_that_land/domain/entities/lines_that_land_tip.dart';
import 'package:appwizard/features/lines_that_land/domain/repositories/lines_that_land_repository.dart';
import 'package:appwizard/features/lines_that_land/presentation/bloc/lines_that_land_bloc.dart';
import 'package:appwizard/features/lines_that_land/presentation/bloc/lines_that_land_event.dart';
import 'package:appwizard/features/lines_that_land/presentation/bloc/lines_that_land_state.dart';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

LinesThatLandFeed _feed(String id, {LinesFeedSource source = LinesFeedSource.cache, bool stale = false}) =>
    LinesThatLandFeed(
      categories: [
        LinesThatLandCategory(
          id: id,
          name: MultilocaleText({'en': id}),
          dailyTip: const LinesThatLandTip(text: MultilocaleText('Hi')),
        ),
      ],
      refreshInterval: const Duration(hours: 24),
      source: source,
      isStale: stale,
    );

class _FakeRepo implements LinesThatLandRepository {
  LinesThatLandFeed? cache;
  Either<Failure, LinesThatLandFeed> Function() onRefresh = () => Right(_feed('fresh', source: LinesFeedSource.network));
  int refreshes = 0;
  Completer<void>? gate;

  @override
  LinesThatLandFeed? cached() => cache;

  @override
  Future<Either<Failure, LinesThatLandFeed>> refresh() async {
    refreshes++;
    if (gate != null) await gate!.future;
    return onRefresh();
  }

  @override
  Future<Either<Failure, LinesThatLandFeed>> getFeed() async => refresh();

  @override
  Future<Either<Failure, List<LinesThatLandCategory>>> getDailyCategories() async => (await getFeed()).map((f) => f.categories);
}

void main() {
  late _FakeRepo repo;
  late LinesThatLandBloc bloc;

  setUp(() {
    repo = _FakeRepo();
    bloc = LinesThatLandBloc(repo);
  });

  tearDown(() => bloc.close());

  String idOf(LinesThatLandState s) => (s as LinesThatLandLoaded).categories.single.id;

  test('priming shows the on-device copy and never calls the endpoint', () async {
    repo.cache = _feed('cached', stale: true);

    bloc.add(const LinesThatLandPrimed());
    await pumpEventQueue();

    expect(idOf(bloc.state), 'cached');
    expect((bloc.state as LinesThatLandLoaded).isStale, isTrue);
    expect(repo.refreshes, 0);
  });

  test('priming without a cache leaves the initial state (nothing to show, nothing fetched)', () async {
    bloc.add(const LinesThatLandPrimed());
    await pumpEventQueue();

    expect(bloc.state, isA<LinesThatLandInitial>());
    expect(repo.refreshes, 0);
  });

  test('opening with a fresh cache does not refresh', () async {
    repo.cache = _feed('cached');

    bloc.add(const LinesThatLandOpened());
    await pumpEventQueue();

    expect(idOf(bloc.state), 'cached');
    expect(repo.refreshes, 0);
  });

  test('opening with a stale cache keeps it on screen while refreshing in the background', () async {
    repo.cache = _feed('cached', stale: true);
    repo.gate = Completer<void>();

    bloc.add(const LinesThatLandOpened());
    await pumpEventQueue();

    final during = bloc.state as LinesThatLandLoaded;
    expect(during.categories.single.id, 'cached');
    expect(during.isRefreshing, isTrue);

    repo.gate!.complete();
    await pumpEventQueue();

    final after = bloc.state as LinesThatLandLoaded;
    expect(after.categories.single.id, 'fresh');
    expect(after.isRefreshing, isFalse);
    expect(after.isStale, isFalse);
    expect(repo.refreshes, 1);
  });

  test('opening with nothing cached shows loading, then the result', () async {
    repo.gate = Completer<void>();

    bloc.add(const LinesThatLandOpened());
    await pumpEventQueue();
    expect(bloc.state, isA<LinesThatLandLoading>());

    repo.gate!.complete();
    await pumpEventQueue();
    expect(idOf(bloc.state), 'fresh');
  });

  test('a failed refresh keeps the content and reports the error once', () async {
    repo.cache = _feed('cached', stale: true);
    repo.onRefresh = () => const Left(NetworkFailure('offline'));
    bloc.add(const LinesThatLandPrimed());
    await pumpEventQueue();

    bloc.add(const LinesThatLandRefreshRequested());
    await pumpEventQueue();

    final state = bloc.state as LinesThatLandLoaded;
    expect(state.categories.single.id, 'cached');
    expect(state.refreshError, 'offline');
    expect(state.isRefreshing, isFalse);

    // the next refresh clears the error while running
    repo.gate = Completer<void>();
    bloc.add(const LinesThatLandRefreshRequested());
    await pumpEventQueue();
    expect((bloc.state as LinesThatLandLoaded).refreshError, isNull);
    repo.gate!.complete();
  });

  test('a failed refresh with nothing cached is an error state', () async {
    repo.onRefresh = () => const Left(NetworkFailure('offline'));

    bloc.add(const LinesThatLandRefreshRequested());
    await pumpEventQueue();

    expect(bloc.state, const LinesThatLandError('offline'));
  });

  test('concurrent refresh requests collapse into one call', () async {
    repo.cache = _feed('cached', stale: true);
    repo.gate = Completer<void>();

    bloc
      ..add(const LinesThatLandOpened())
      ..add(const LinesThatLandRefreshRequested())
      ..add(const LinesThatLandOpened());
    await pumpEventQueue();
    repo.gate!.complete();
    await pumpEventQueue();

    expect(repo.refreshes, 1);
    expect(idOf(bloc.state), 'fresh');
  });
}
