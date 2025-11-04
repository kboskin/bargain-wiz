import '../base_bloc.dart';
import '../../../domain/entities/example_entity.dart';

/// Example states for BLoC
abstract class ExampleState extends BaseState {
  const ExampleState();
}

class ExampleInitial extends ExampleState {
  const ExampleInitial();
}

class ExampleLoading extends ExampleState {
  const ExampleLoading();
}

class ExampleLoaded extends ExampleState {
  final ExampleEntity entity;

  const ExampleLoaded(this.entity);

  @override
  List<Object> get props => [entity];
}

class ExampleError extends ExampleState {
  final String message;

  const ExampleError(this.message);

  @override
  List<Object> get props => [message];
}

