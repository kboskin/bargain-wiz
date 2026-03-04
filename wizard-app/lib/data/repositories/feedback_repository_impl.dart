import 'package:dartz/dartz.dart';

import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/data/datasources/feedback_remote_datasource.dart';
import 'package:appwizard/data/mappers/feedback_form_mapper.dart';
import 'package:appwizard/domain/entities/feedback_form_config.dart';
import 'package:appwizard/domain/repositories/feedback_repository.dart';

class FeedbackRepositoryImpl implements FeedbackRepository {
  FeedbackRepositoryImpl(
    this._dataSource,
    this._mapper,
    this._logger,
  );

  final FeedbackRemoteDataSource _dataSource;
  final FeedbackFormMapper _mapper;
  final AppLogger _logger;

  @override
  Future<Either<Failure, FeedbackFormConfig>> getFeedbackFormConfig() async {
    try {
      final model = await _dataSource.getFeedbackFormConfig();
      if (model == null) {
        return Left(CacheFailure('Feedback form config not available'));
      }
      return Right(_mapper.toEntity(model));
    } on Object catch (e, stackTrace) {
      _logger.e('getFeedbackFormConfig failed', e, stackTrace);
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> submitFeedback(
    Map<String, String> values,
    String submitUrl,
  ) async {
    try {
      await _dataSource.submitFeedback(values, submitUrl);
      return const Right(null);
    } on Object catch (e, stackTrace) {
      _logger.e('submitFeedback failed', e, stackTrace);
      return Left(ServerFailure(e.toString()));
    }
  }
}
