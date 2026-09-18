import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:appwizard/features/lines_that_land/domain/repositories/lines_that_land_repository.dart';
import 'package:appwizard/features/lines_that_land/presentation/bloc/lines_that_land_event.dart';
import 'package:appwizard/features/lines_that_land/presentation/bloc/lines_that_land_state.dart';
import 'package:appwizard/features/shared/presentation/bloc/base_bloc.dart';

/// "Lines that land": cache first, network in the background.
///
/// Nothing is fetched at app start. [LinesThatLandPrimed] only reads the on-device copy so
/// the tab renders instantly; [LinesThatLandOpened] (tab shown) refreshes in the background
/// when that copy is stale or missing; [LinesThatLandRefreshRequested] is the user's pull to
/// refresh. Content already on screen is never replaced by a spinner or an error.
class LinesThatLandBloc extends BaseBloc<LinesThatLandEvent, LinesThatLandState> {
  LinesThatLandBloc(this._repository) : super(const LinesThatLandInitial()) {
    on<LinesThatLandPrimed>(_onPrimed);
    on<LinesThatLandOpened>(_onOpened);
    on<LinesThatLandRefreshRequested>(_onRefreshRequested);
  }

  final LinesThatLandRepository _repository;
  bool _refreshing = false;

  Future<void> _onPrimed(LinesThatLandPrimed event, Emitter<LinesThatLandState> emit) async {
    if (state is! LinesThatLandInitial) return;
    final cached = _repository.cached();
    if (cached != null) emit(LinesThatLandLoaded.fromFeed(cached));
  }

  Future<void> _onOpened(LinesThatLandOpened event, Emitter<LinesThatLandState> emit) async {
    if (_refreshing) return;
    var current = state;
    if (current is LinesThatLandInitial) {
      final cached = _repository.cached();
      if (cached != null) emit(current = LinesThatLandLoaded.fromFeed(cached));
    }
    if (current is LinesThatLandLoaded && !current.isStale) return;
    await _refresh(emit);
  }

  Future<void> _onRefreshRequested(LinesThatLandRefreshRequested event, Emitter<LinesThatLandState> emit) async {
    if (_refreshing) return;
    await _refresh(emit);
  }

  Future<void> _refresh(Emitter<LinesThatLandState> emit) async {
    _refreshing = true;
    final before = state;
    if (before is LinesThatLandLoaded) {
      emit(before.copyWith(isRefreshing: true, clearError: true));
    } else {
      emit(const LinesThatLandLoading());
    }
    final result = await _repository.refresh();
    _refreshing = false;
    result.fold(
      (failure) {
        final now = state;
        if (now is LinesThatLandLoaded) {
          emit(now.copyWith(isRefreshing: false, refreshError: failure.message));
        } else {
          emit(LinesThatLandError(failure.message));
        }
      },
      (feed) => emit(LinesThatLandLoaded.fromFeed(feed)),
    );
  }
}
