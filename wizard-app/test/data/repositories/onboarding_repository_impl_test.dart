import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:appwizard/data/repositories/onboarding_repository_impl.dart';
import 'package:appwizard/domain/entities/onboarding_data_entity.dart';
import 'package:appwizard/data/datasources/onboarding_local_datasource.dart';
import 'package:appwizard/data/models/onboarding_data.dart';
import 'package:appwizard/core/error/failures.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'onboarding_repository_impl_test.mocks.dart';

@GenerateMocks([OnboardingLocalDataSource])
void main() {
  late OnboardingRepositoryImpl repository;
  late MockOnboardingLocalDataSource mockDataSource;

  setUp(() {
    mockDataSource = MockOnboardingLocalDataSource();
    repository = OnboardingRepositoryImpl(mockDataSource);
  });

  group('saveOnboardingData', () {
    test('should return Right(null) when save is successful', () async {
      // Arrange
      final entity = OnboardingDataEntity(
        answers: [
          OnboardingAnswer(
            screenIndex: 0,
            screenTitle: 'Test Screen',
            screenType: 'select',
            answerKey: 'favorite_marketplace',
            answer: 'ebay',
          ),
        ],
        isCompleted: true,
      );

      when(mockDataSource.saveOnboardingData(any))
          .thenAnswer((_) async => Future.value());

      // Act
      final result = await repository.saveOnboardingData(entity);

      // Assert
      expect(result, isA<Right<Failure, void>>());
      verify(mockDataSource.saveOnboardingData(any)).called(1);
    });

    test('should return Left(CacheFailure) when save fails', () async {
      // Arrange
      final entity = OnboardingDataEntity(
        answers: [],
        isCompleted: false,
      );

      when(mockDataSource.saveOnboardingData(any))
          .thenThrow(Exception('Save failed'));

      // Act
      final result = await repository.saveOnboardingData(entity);

      // Assert
      expect(result, isA<Left<Failure, void>>());
      expect((result as Left).value, isA<CacheFailure>());
    });
  });

  group('getOnboardingData', () {
    test('should return Right(entity) when data exists', () async {
      // Arrange
      final data = OnboardingData(
        isCompleted: true,
        answers: {
          'favorite_marketplace': 'ebay',
        },
      );

      when(mockDataSource.getOnboardingData())
          .thenAnswer((_) async => data);

      // Act
      final result = await repository.getOnboardingData();

      // Assert
      expect(result, isA<Right<Failure, OnboardingDataEntity?>>());
      final entity = (result as Right).value;
      expect(entity, isNotNull);
      expect(entity!.isCompleted, equals(true));
      expect(entity.answers.length, equals(1));
      verify(mockDataSource.getOnboardingData()).called(1);
    });

    test('should return Right(null) when no data exists', () async {
      // Arrange
      when(mockDataSource.getOnboardingData())
          .thenAnswer((_) async => null);

      // Act
      final result = await repository.getOnboardingData();

      // Assert
      expect(result, isA<Right<Failure, OnboardingDataEntity?>>());
      expect((result as Right).value, isNull);
      verify(mockDataSource.getOnboardingData()).called(1);
    });

    test('should return Left(CacheFailure) when get fails', () async {
      // Arrange
      when(mockDataSource.getOnboardingData())
          .thenThrow(Exception('Get failed'));

      // Act
      final result = await repository.getOnboardingData();

      // Assert
      expect(result, isA<Left<Failure, OnboardingDataEntity?>>());
      expect((result as Left).value, isA<CacheFailure>());
    });
  });

  group('clearOnboardingData', () {
    test('should return Right(null) when clear is successful', () async {
      // Arrange
      when(mockDataSource.clearOnboardingData())
          .thenAnswer((_) async => Future.value());

      // Act
      final result = await repository.clearOnboardingData();

      // Assert
      expect(result, isA<Right<Failure, void>>());
      verify(mockDataSource.clearOnboardingData()).called(1);
    });

    test('should return Left(CacheFailure) when clear fails', () async {
      // Arrange
      when(mockDataSource.clearOnboardingData())
          .thenThrow(Exception('Clear failed'));

      // Act
      final result = await repository.clearOnboardingData();

      // Assert
      expect(result, isA<Left<Failure, void>>());
      expect((result as Left).value, isA<CacheFailure>());
    });
  });

  group('isOnboardingCompleted', () {
    test('should return Right(true) when onboarding is completed', () async {
      // Arrange
      final data = OnboardingData(
        isCompleted: true,
        answers: {},
      );

      when(mockDataSource.getOnboardingData())
          .thenAnswer((_) async => data);

      // Act
      final result = await repository.isOnboardingCompleted();

      // Assert
      expect(result, isA<Right<Failure, bool>>());
      expect((result as Right).value, equals(true));
    });

    test('should return Right(false) when onboarding is not completed', () async {
      // Arrange
      final data = OnboardingData(
        isCompleted: false,
        answers: {},
      );

      when(mockDataSource.getOnboardingData())
          .thenAnswer((_) async => data);

      // Act
      final result = await repository.isOnboardingCompleted();

      // Assert
      expect(result, isA<Right<Failure, bool>>());
      expect((result as Right).value, equals(false));
    });

    test('should return Right(false) when no data exists', () async {
      // Arrange
      when(mockDataSource.getOnboardingData())
          .thenAnswer((_) async => null);

      // Act
      final result = await repository.isOnboardingCompleted();

      // Assert
      expect(result, isA<Right<Failure, bool>>());
      expect((result as Right).value, equals(false));
    });

    test('should return Left(CacheFailure) when get fails', () async {
      // Arrange
      when(mockDataSource.getOnboardingData())
          .thenThrow(Exception('Get failed'));

      // Act
      final result = await repository.isOnboardingCompleted();

      // Assert
      expect(result, isA<Left<Failure, bool>>());
      expect((result as Left).value, isA<CacheFailure>());
    });
  });

  group('_entityToData conversion', () {
    test('should convert entity with answerKey to data correctly', () async {
      // Arrange
      final entity = OnboardingDataEntity(
        answers: [
          OnboardingAnswer(
            screenIndex: 0,
            screenTitle: 'Test',
            screenType: 'select',
            answerKey: 'favorite_marketplace',
            answer: 'ebay',
          ),
        ],
        isCompleted: true,
      );

      when(mockDataSource.saveOnboardingData(any))
          .thenAnswer((_) async => Future.value());

      // Act
      await repository.saveOnboardingData(entity);

      // Assert
      verify(mockDataSource.saveOnboardingData(
        argThat(
          predicate<OnboardingData>(
            (data) =>
                data.isCompleted == true &&
                data.answers['favorite_marketplace'] == 'ebay',
          ),
        ),
      )).called(1);
    });

    test('should use screen index as key when answerKey is null', () async {
      // Arrange
      final entity = OnboardingDataEntity(
        answers: [
          OnboardingAnswer(
            screenIndex: 2,
            screenTitle: 'Test',
            screenType: 'select',
            answerKey: null,
            answer: 'value',
          ),
        ],
        isCompleted: false,
      );

      when(mockDataSource.saveOnboardingData(any))
          .thenAnswer((_) async => Future.value());

      // Act
      await repository.saveOnboardingData(entity);

      // Assert
      verify(mockDataSource.saveOnboardingData(
        argThat(
          predicate<OnboardingData>(
            (data) => data.answers.containsKey('screen_2'),
          ),
        ),
      )).called(1);
    });
  });
}

