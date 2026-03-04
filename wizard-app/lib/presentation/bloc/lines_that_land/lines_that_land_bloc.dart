import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:appwizard/domain/repositories/lines_that_land_repository.dart';
import 'package:appwizard/presentation/bloc/base_bloc.dart';
import 'package:appwizard/presentation/bloc/lines_that_land/lines_that_land_event.dart';
import 'package:appwizard/presentation/bloc/lines_that_land/lines_that_land_state.dart';

/// BLoC for "Lines that land" – single API call, result cached in state.
class LinesThatLandBloc extends BaseBloc<LinesThatLandEvent, LinesThatLandState> {
  LinesThatLandBloc(this._repository) : super(const LinesThatLandInitial()) {
    on<LoadLinesThatLandRequested>(_onLoadRequested);
  }

  final LinesThatLandRepository _repository;

  Future<void> _onLoadRequested(
    LoadLinesThatLandRequested event,
    Emitter<LinesThatLandState> emit,
  ) async {
    if (state is LinesThatLandLoaded) return;
    if (state is LinesThatLandLoading) return;

    emit(const LinesThatLandLoading());
    // Simulate network latency so the loading animation is visible in the bottom sheet.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final result = await _repository.getDailyCategories();
    result.fold(
      (failure) => emit(LinesThatLandError(failure.message)),
      (list) => emit(LinesThatLandLoaded(list)),
    );
  }
}
