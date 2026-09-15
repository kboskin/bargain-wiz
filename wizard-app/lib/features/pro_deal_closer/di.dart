import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:appwizard/features/pro_deal_closer/data/datasources/pro_deal_closer_remote_datasource.dart';
import 'package:appwizard/features/pro_deal_closer/data/mappers/pro_deal_closer_mapper.dart';
import 'package:appwizard/features/pro_deal_closer/data/repositories/pro_deal_closer_repository_impl.dart';
import 'package:appwizard/features/pro_deal_closer/domain/repositories/pro_deal_closer_repository.dart';
import 'package:appwizard/features/pro_deal_closer/presentation/cubit/pro_deal_closer_cubit.dart';
import 'package:get_it/get_it.dart';

/// Feature-local dependency registration for `pro_deal_closer`.
/// Called from core/di/injection_container.dart after core services
/// ([AppLogger], [ConversationRepository]) are registered.
void registerProDealCloserDependencies(GetIt sl) {
  sl
    ..registerLazySingleton<ProDealCloserRemoteDataSource>(
      () => MockProDealCloserRemoteDataSource(sl<AppLogger>()),
    )
    ..registerLazySingleton<WizardReplyMapper>(WizardReplyMapper.new)
    ..registerLazySingleton<DealOptionsMapper>(DealOptionsMapper.new)
    ..registerLazySingleton<ProDealCloserRepository>(
      () => ProDealCloserRepositoryImpl(
        sl<ProDealCloserRemoteDataSource>(),
        sl<WizardReplyMapper>(),
        sl<DealOptionsMapper>(),
        sl<AppLogger>(),
      ),
    )
    ..registerFactory<ProDealCloserCubit>(
      () => ProDealCloserCubit(
        repository: sl<ProDealCloserRepository>(),
        conversationRepository: sl<ConversationRepository>(),
        logger: sl<AppLogger>(),
      ),
    );
}
