import 'package:dartz/dartz.dart';
import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/features/onboarding/domain/entities/onboarding_data_entity.dart';

/// Repository interface for onboarding data
abstract class OnboardingRepository {
  /// Save onboarding data
  Future<Either<Failure, void>> saveOnboardingData(OnboardingDataEntity data);
  
  /// Get onboarding data
  Future<Either<Failure, OnboardingDataEntity?>> getOnboardingData();
  
  /// Clear onboarding data
  Future<Either<Failure, void>> clearOnboardingData();
  
  /// Check if onboarding is completed
  Future<Either<Failure, bool>> isOnboardingCompleted();

  /// Upload all user/onboarding data to the backend.
  /// Completes when the backend responds (success or failure).
  Future<Either<Failure, void>> uploadUserData(OnboardingDataEntity data);
}

