import 'package:dartz/dartz.dart';

import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/core/network/cloud_functions_client.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/express_dealmaker/data/datasources/express_dealmaker_remote_datasource.dart';
import 'package:appwizard/features/express_dealmaker/data/mappers/express_dealmaker_mapper.dart';
import 'package:appwizard/features/express_dealmaker/domain/entities/deal_reply.dart';
import 'package:appwizard/features/express_dealmaker/domain/entities/upload_screenshot_result.dart';
import 'package:appwizard/features/express_dealmaker/domain/repositories/express_dealmaker_repository.dart';

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
  Future<Either<Failure, UploadScreenshotResult>> uploadScreenshot(final String filePath) async {
    try {
      final dto = await _remote.uploadScreenshot(filePath);
      return Right(_uploadResultMapper.toEntity(dto));
    } on Object catch (e, stackTrace) {
      _logger.e('Express Dealmaker upload failed', e, stackTrace);
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, DealReply>> getDealReply({
    required final List<String> uploadedIds,
    required final String locale,
    final String? keyword,
    final Map<String, dynamic> overrides = const {},
    final String? conversationId,
  }) async {
    try {
      final dto = await _remote.getDealReply(
        uploadedIds: uploadedIds,
        keyword: keyword,
        locale: locale,
        overrides: overrides,
        conversationId: conversationId,
      );
      return Right(_dealReplyMapper.toEntity(dto));
    } on Object catch (e, stackTrace) {
      _logger.e('Express Dealmaker getDealReply failed', e, stackTrace);
      return Left(_failure(e));
    }
  }

  /// A generation failure keeps the conversation it belongs to, so the cubit can retry it as a
  /// regeneration. Everything else only carries a message — the backend's when it sent one,
  /// because `toString()` on an exception is not copy a buyer should read.
  static Failure _failure(final Object e) => switch (e) {
        ExpressGenerationException() => GenerationFailure(e.message, conversationId: e.conversationId),
        CloudFunctionException() => ServerFailure(e.message),
        _ => ServerFailure(e.toString()),
      };
}
