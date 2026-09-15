import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/pro_deal_closer/data/datasources/pro_deal_closer_remote_datasource.dart';
import 'package:appwizard/features/pro_deal_closer/data/mappers/pro_deal_closer_mapper.dart';
import 'package:appwizard/features/pro_deal_closer/domain/entities/wizard_reply.dart';
import 'package:appwizard/features/pro_deal_closer/domain/repositories/pro_deal_closer_repository.dart';
import 'package:dartz/dartz.dart';

class ProDealCloserRepositoryImpl implements ProDealCloserRepository {
  ProDealCloserRepositoryImpl(
    this._remote,
    this._replyMapper,
    this._optionsMapper,
    this._logger,
  );

  final ProDealCloserRemoteDataSource _remote;
  final WizardReplyMapper _replyMapper;
  final DealOptionsMapper _optionsMapper;
  final AppLogger _logger;

  @override
  Future<Either<Failure, WizardReply>> getReply({
    required List<ProDealCloserMessage> history,
    required String vibe,
    required String locale,
    bool regenerate = false,
  }) async {
    try {
      final dto = await _remote.getReply(
        history: history,
        vibe: vibe,
        locale: locale,
        regenerate: regenerate,
      );
      return Right(_replyMapper.toEntity(dto));
    } on Object catch (e, stackTrace) {
      _logger.e('Pro Deal Closer getReply failed', e, stackTrace);
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<DealLine>>> getOptions({
    required List<ProDealCloserMessage> history,
    required String vibe,
    required String locale,
  }) async {
    try {
      final dtos = await _remote.getOptions(history: history, vibe: vibe, locale: locale);
      return Right(_optionsMapper.toEntities(dtos));
    } on Object catch (e, stackTrace) {
      _logger.e('Pro Deal Closer getOptions failed', e, stackTrace);
      return Left(ServerFailure(e.toString()));
    }
  }
}
