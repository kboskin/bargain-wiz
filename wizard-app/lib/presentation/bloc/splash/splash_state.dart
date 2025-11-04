import '../base_bloc.dart';

/// States for splash screen BLoC
abstract class SplashState extends BaseState {
  const SplashState();
}

/// Initial state - splash screen is showing
class SplashInitial extends SplashState {
  const SplashInitial();
}

/// Splash screen is complete and ready to navigate
class SplashCompleted extends SplashState {
  const SplashCompleted();
}

