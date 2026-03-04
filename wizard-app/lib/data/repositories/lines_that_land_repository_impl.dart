import 'package:dartz/dartz.dart';

import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/data/datasources/lines_that_land_remote_datasource.dart';
import 'package:appwizard/data/mappers/lines_that_land_mapper.dart';
import 'package:appwizard/domain/entities/lines_that_land_category.dart';
import 'package:appwizard/domain/repositories/lines_that_land_repository.dart';

class LinesThatLandRepositoryImpl implements LinesThatLandRepository {
  LinesThatLandRepositoryImpl(this._dataSource, this._mapper, this._logger);

  final LinesThatLandRemoteDataSource _dataSource;
  final LinesThatLandMapper _mapper;
  final AppLogger _logger;

  static final DateTime _epoch = DateTime.utc(2025, 1, 1);

  @override
  Future<Either<Failure, List<LinesThatLandCategory>>> getDailyCategories() async {
    try {
      final raw = await _dataSource.getCategories();
      final models = _mapper.toCategoryModels(raw);
      if (models.isEmpty) {
        return const Right([]);
      }
      final today = DateTime.now().toUtc();
      final dayIndex = today.difference(_epoch).inDays;
      final entities = _mapper.toCategoryEntities(models, dayIndex);
      return Right(entities);
    } on Object catch (e, stackTrace) {
      _logger.e('LinesThatLandRepository.getDailyCategories failed', e, stackTrace);
      return Left(CacheFailure(e.toString()));
    }
  }
}
