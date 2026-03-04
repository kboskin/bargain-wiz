import 'package:dartz/dartz.dart';
import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/data/datasources/express_dealmaker_remote_datasource.dart';
import 'package:appwizard/data/mappers/express_dealmaker_mapper.dart';
import 'package:appwizard/domain/entities/deal_reply.dart';
import 'package:appwizard/domain/entities/upload_screenshot_result.dart';
import 'package:appwizard/domain/repositories/express_dealmaker_repository.dart';

class ExpressDealmakerRepositoryImpl implements ExpressDealmakerRepository {
  ExpressDealmakerRepositoryImpl(
    this._remote,
    this._uploadResultMapper,
    this._dealReplyMapper,
    this._logger,
  );

  final ExpressDealmakerRemoteDataSource _remote;
  final UploadScreenshotResultMapper _uploadResultMapper;
  final DealReplyMapper _dealReplyMapper;
  final AppLogger _logger;

  @override
  Future<Either<Failure, UploadScreenshotResult>> uploadScreenshot(String filePath) async {
    try {
      final dto = await _remote.uploadScreenshot(filePath);
      return Right(_uploadResultMapper.toEntity(dto));
    } catch (e, stackTrace) {
      _logger.e('Express Dealmaker upload failed', e, stackTrace);
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, DealReply>> getDealReply({
    required List<String> uploadedIds,
    String? keyword,
    required String locale,
  }) async {
    try {
      final dto = await _remote.getDealReply(
        uploadedIds: uploadedIds,
        keyword: keyword,
        locale: locale,
      );
      return Right(_dealReplyMapper.toEntity(dto));
    } catch (e, stackTrace) {
      _logger.e('Express Dealmaker getDealReply failed', e, stackTrace);
      return Left(ServerFailure(e.toString()));
    }
  }
}
