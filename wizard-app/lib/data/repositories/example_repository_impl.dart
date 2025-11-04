import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/error/exceptions.dart';
import '../../core/network/network_info.dart';
import '../../domain/entities/example_entity.dart';
import '../../domain/repositories/repository.dart';
import '../datasources/example_remote_datasource.dart';
import '../datasources/example_local_datasource.dart';
import '../mappers/entity_mapper.dart';

/// Example repository implementation
class ExampleRepositoryImpl implements Repository<ExampleEntity> {
  final ExampleRemoteDataSource remoteDataSource;
  final ExampleLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  ExampleRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, ExampleEntity>> getData() async {
    if (await networkInfo.isConnected) {
      try {
        final remoteModel = await remoteDataSource.getData();
        final entity = remoteModel.toEntity();
        
        // Cache the data for offline access
        await localDataSource.cacheData(remoteModel);
        
        return Right(entity);
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } catch (e) {
        return Left(ServerFailure('Unexpected error: $e'));
      }
    } else {
      try {
        final localModel = await localDataSource.getData();
        final entity = localModel.toEntity();
        return Right(entity);
      } on CacheException catch (e) {
        return Left(CacheFailure(e.message));
      } catch (e) {
        return Left(CacheFailure('Unexpected error: $e'));
      }
    }
  }
}

