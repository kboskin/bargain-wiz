import 'package:dartz/dartz.dart';
import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/core/error/exceptions.dart';
import 'package:appwizard/core/network/network_info.dart';
import 'package:appwizard/domain/repositories/repository.dart';

/// Base implementation for repositories
/// This follows the Repository pattern from Clean Architecture
abstract class RepositoryImpl<T> implements Repository<T> {
  final NetworkInfo networkInfo;

  RepositoryImpl(this.networkInfo);

  @override
  Future<Either<Failure, T>> getData() async {
    if (await networkInfo.isConnected) {
      try {
        final remoteData = await getRemoteData();
        return Right(remoteData);
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } catch (e) {
        return Left(ServerFailure(e.toString()));
      }
    } else {
      try {
        final localData = await getLocalData();
        return Right(localData);
      } on CacheException catch (e) {
        return Left(CacheFailure(e.message));
      } catch (e) {
        return Left(CacheFailure(e.toString()));
      }
    }
  }

  /// Get data from remote source
  Future<T> getRemoteData();

  /// Get data from local source
  Future<T> getLocalData();
}

