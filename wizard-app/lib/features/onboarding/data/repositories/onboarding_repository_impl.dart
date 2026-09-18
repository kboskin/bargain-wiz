import 'package:dartz/dartz.dart';
import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:appwizard/features/onboarding/domain/entities/onboarding_data_entity.dart';
import 'package:appwizard/features/onboarding/data/datasources/onboarding_local_datasource.dart';
import 'package:appwizard/features/onboarding/data/mappers/onboarding_data_mapper.dart';

/// Implementation of OnboardingRepository
class OnboardingRepositoryImpl implements OnboardingRepository {
  /// [uploader] pushes completed onboarding data to the profile endpoint (resolved lazily
  /// to avoid a dependency cycle with the profile services).
  OnboardingRepositoryImpl(this.localDataSource, this._mapper, this._logger, {this.uploader});

  final OnboardingLocalDataSource localDataSource;
  final OnboardingDataMapper _mapper;
  final AppLogger _logger;
  final Future<void> Function(OnboardingDataEntity data)? uploader;

  @override
  Future<Either<Failure, void>> saveOnboardingData(OnboardingDataEntity entity) async {
    try {
      final data = _mapper.toModel(entity);
      await localDataSource.saveOnboardingData(data);
      return const Right(null);
    } catch (e, stackTrace) {
      _logger.e('Error saving onboarding data', e, stackTrace);
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, OnboardingDataEntity?>> getOnboardingData() async {
    try {
      final data = await localDataSource.getOnboardingData();
      if (data == null) return const Right(null);
      return Right(_mapper.toEntity(data));
    } catch (e, stackTrace) {
      _logger.e('Error loading onboarding data', e, stackTrace);
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> clearOnboardingData() async {
    try {
      await localDataSource.clearOnboardingData();
      return const Right(null);
    } catch (e, stackTrace) {
      _logger.e('Error clearing onboarding data', e, stackTrace);
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isOnboardingCompleted() async {
    try {
      final data = await localDataSource.getOnboardingData();
      return Right(data?.isCompleted ?? false);
    } catch (e, stackTrace) {
      _logger.e('Error checking onboarding completed', e, stackTrace);
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> uploadUserData(
      OnboardingDataEntity entity) async {
    // Best effort: onboarding must complete even when the backend is unreachable; the
    // sync service retries and every later profile change pushes the full state again.
    try {
      await uploader?.call(entity);
    } catch (e, stackTrace) {
      _logger.w('Onboarding profile upload deferred: $e');
      _logger.e('Error uploading onboarding user data', e, stackTrace);
    }
    return const Right(null);
  }
}

