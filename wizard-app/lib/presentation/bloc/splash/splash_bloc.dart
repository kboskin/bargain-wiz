import 'package:flutter_bloc/flutter_bloc.dart';
import '../base_bloc.dart';
import 'splash_event.dart';
import 'splash_state.dart';

/// BLoC for managing splash screen state
class SplashBloc extends BaseBloc<SplashEvent, SplashState> {
  SplashBloc() : super(const SplashInitial()) {
    on<SplashInitialized>(_onSplashInitialized);
  }

  void _onSplashInitialized(
    SplashInitialized event,
    Emitter<SplashState> emit,
  ) {
    emit(const SplashCompleted());
  }
}

