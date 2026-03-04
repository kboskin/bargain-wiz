import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

/// Base BLoC class for all BLoCs
abstract class BaseBloc<Event extends Equatable, State extends Equatable>
    extends Bloc<Event, State> {
  BaseBloc(super.initialState);
}

/// Base BLoC state class
abstract class BaseState extends Equatable {
  const BaseState();

  @override
  List<Object?> get props => [];
}

/// Base BLoC event class
abstract class BaseEvent extends Equatable {
  const BaseEvent();

  @override
  List<Object?> get props => [];
}

