import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/usecase/usecase.dart';
import '../entities/example_entity.dart';
import '../repositories/repository.dart';

/// Example use case demonstrating the pattern
class GetExampleUseCase implements UseCase<ExampleEntity, NoParams> {
  final Repository<ExampleEntity> repository;

  GetExampleUseCase(this.repository);

  @override
  Future<Either<Failure, ExampleEntity>> call(NoParams params) async {
    return await repository.getData();
  }
}

