import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';

/// Base repository interface
/// T - Entity type
abstract class Repository<T> {
  Future<Either<Failure, T>> getData();
}

