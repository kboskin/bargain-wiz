import 'package:equatable/equatable.dart';
import 'package:dartz/dartz.dart';
import '../error/failures.dart';

// Note: Either<Failure, T> is from dartz package
// Left = Failure, Right = Success

/// Base class for all use cases
/// T - return type
/// P - parameters
abstract class UseCase<T, P> {
  Future<Either<Failure, T>> call(P params);
}

/// Use case with no parameters
abstract class NoParamsUseCase<T> {
  Future<Either<Failure, T>> call();
}

class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object> get props => [];
}

