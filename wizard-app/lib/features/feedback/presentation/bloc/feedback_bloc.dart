import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:appwizard/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:appwizard/features/shared/presentation/bloc/base_bloc.dart';
import 'package:appwizard/features/feedback/presentation/bloc/feedback_event.dart';
import 'package:appwizard/features/feedback/presentation/bloc/feedback_state.dart';

/// BLoC for feedback form: load config from RC, submit to backend.
class FeedbackBloc extends BaseBloc<FeedbackEvent, FeedbackState> {
  FeedbackBloc(this._repository) : super(const FeedbackInitial()) {
    on<LoadFeedbackFormRequested>(_onLoadFormRequested);
    on<FeedbackSubmitted>(_onFeedbackSubmitted);
  }

  final FeedbackRepository _repository;

  Future<void> _onLoadFormRequested(
    LoadFeedbackFormRequested event,
    Emitter<FeedbackState> emit,
  ) async {
    if (state is FeedbackLoaded) return;
    if (state is FeedbackLoading) return;

    emit(const FeedbackLoading());
    final result = await _repository.getFeedbackFormConfig();
    result.fold(
      (failure) => emit(FeedbackError(failure.message)),
      (config) => emit(FeedbackLoaded(config)),
    );
  }

  Future<void> _onFeedbackSubmitted(
    FeedbackSubmitted event,
    Emitter<FeedbackState> emit,
  ) async {
    final current = state;
    if (current is! FeedbackLoaded) return;

    emit(const FeedbackSubmitting());
    final result = await _repository.submitFeedback(
      event.values,
      current.config.submitUrl,
    );
    result.fold(
      (failure) => emit(FeedbackError(failure.message)),
      (_) => emit(const FeedbackSubmitSuccess()),
    );
  }
}
