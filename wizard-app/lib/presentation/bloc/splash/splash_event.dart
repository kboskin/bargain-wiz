import '../base_bloc.dart';

/// Events for splash screen BLoC
abstract class SplashEvent extends BaseEvent {
  const SplashEvent();
}

/// Event fired when app initialization is complete
class SplashInitialized extends SplashEvent {
  const SplashInitialized();
}

