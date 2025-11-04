import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../base_bloc.dart';
import 'example_event.dart';
import 'example_state.dart';
import '../../../core/error/failures.dart';
import '../../../core/usecase/usecase.dart';
import '../../../domain/usecases/example_usecase.dart';
import '../../../domain/entities/example_entity.dart';

/// Example BLoC demonstrating the pattern
class ExampleBloc extends BaseBloc<ExampleEvent, ExampleState> {
  final GetExampleUseCase getExampleUseCase;

  ExampleBloc({
    required this.getExampleUseCase,
  }) : super(const ExampleInitial()) {
    on<LoadExampleEvent>(_onLoadExample);
    on<RefreshExampleEvent>(_onRefreshExample);
  }

  Future<void> _onLoadExample(
    LoadExampleEvent event,
    Emitter<ExampleState> emit,
  ) async {
    emit(const ExampleLoading());

    final result = await getExampleUseCase(const NoParams());

    _handleResult(result, emit);
  }

  Future<void> _onRefreshExample(
    RefreshExampleEvent event,
    Emitter<ExampleState> emit,
  ) async {
    emit(const ExampleLoading());

    final result = await getExampleUseCase(const NoParams());

    _handleResult(result, emit);
  }

  void _handleResult(
    Either<Failure, ExampleEntity> result,
    Emitter<ExampleState> emit,
  ) {
    result.fold(
      (failure) => emit(ExampleError(failure.message)),
      (entity) => emit(ExampleLoaded(entity)),
    );
  }
}

