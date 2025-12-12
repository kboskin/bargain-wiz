import 'package:dartz/dartz.dart';
import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/domain/repositories/onboarding_repository.dart';
import 'package:appwizard/domain/entities/onboarding_data_entity.dart';
import 'package:appwizard/data/datasources/onboarding_local_datasource.dart';
import 'package:appwizard/data/models/onboarding_data.dart';

/// Implementation of OnboardingRepository
class OnboardingRepositoryImpl implements OnboardingRepository {
  final OnboardingLocalDataSource localDataSource;

  OnboardingRepositoryImpl(this.localDataSource);

  @override
  Future<Either<Failure, void>> saveOnboardingData(OnboardingDataEntity entity) async {
    try {
      // Convert entity to data model
      final data = _entityToData(entity);
      await localDataSource.saveOnboardingData(data);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, OnboardingDataEntity?>> getOnboardingData() async {
    try {
      final data = await localDataSource.getOnboardingData();
      if (data == null) return const Right(null);
      return Right(_dataToEntity(data));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> clearOnboardingData() async {
    try {
      await localDataSource.clearOnboardingData();
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isOnboardingCompleted() async {
    try {
      final data = await localDataSource.getOnboardingData();
      return Right(data?.isCompleted ?? false);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  /// Convert entity to data model
  /// Answers are stored by their answerKey from the screen configuration
  OnboardingData _entityToData(OnboardingDataEntity entity) {
    final answersMap = <String, dynamic>{};
    
    for (final answer in entity.answers) {
      // Use answerKey if available, otherwise fallback to screen index
      final key = answer.answerKey ?? 'screen_${answer.screenIndex}';
      answersMap[key] = answer.answer;
    }

    return OnboardingData(
      isCompleted: entity.isCompleted,
      answers: answersMap,
    );
  }

  /// Convert data model to entity
  /// Supports both new format (answerKey -> answer) and legacy format (screen_X -> answer data)
  OnboardingDataEntity _dataToEntity(OnboardingData data) {
    final answers = <OnboardingAnswer>[];

    for (final entry in data.answers.entries) {
      try {
        final key = entry.key;
        final answerValue = entry.value;
        
        // Check if this is legacy format (screen_X with full answer data)
        if (key.startsWith('screen_') && answerValue is Map<String, dynamic>) {
          // Legacy format: extract from map
          final index = int.tryParse(key.replaceFirst('screen_', '')) ?? 0;
          answers.add(OnboardingAnswer(
            screenIndex: index,
            screenTitle: answerValue['screenTitle'] as String? ?? '',
            screenType: answerValue['screenType'] as String? ?? '',
            answerKey: answerValue['answerKey'] as String?,
            answer: answerValue['answer'],
          ));
        } else {
          // New format: key is answerKey, value is the answer
          // We need to determine screen index from key (fallback to 0)
          final index = key.startsWith('screen_')
              ? int.tryParse(key.replaceFirst('screen_', '')) ?? 0
              : 0;
          
          answers.add(OnboardingAnswer(
            screenIndex: index,
            screenTitle: '', // Will be filled from config when available
            screenType: '', // Will be filled from config when available
            answerKey: key.startsWith('screen_') ? null : key,
            answer: answerValue,
          ));
        }
      } catch (e) {
        // Skip invalid entries
        continue;
      }
    }

    return OnboardingDataEntity(
      answers: answers,
      isCompleted: data.isCompleted,
    );
  }
}

