import '../base_bloc.dart';

/// Example events for BLoC
abstract class ExampleEvent extends BaseEvent {
  const ExampleEvent();
}

class LoadExampleEvent extends ExampleEvent {
  const LoadExampleEvent();
}

class RefreshExampleEvent extends ExampleEvent {
  const RefreshExampleEvent();
}

