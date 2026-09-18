import 'package:appwizard/core/services/auth_service.dart';
import 'package:appwizard/core/services/user_profile_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/core/utils/screenshot_encoder.dart';
import 'package:appwizard/features/conversation/data/datasources/conversations_api.dart';
import 'package:appwizard/features/conversation/data/datasources/conversations_stream.dart';
import 'package:appwizard/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:appwizard/features/pro_deal_closer/data/repositories/pro_deal_closer_repository_impl.dart';
import 'package:appwizard/features/pro_deal_closer/domain/repositories/pro_deal_closer_repository.dart';
import 'package:appwizard/features/pro_deal_closer/presentation/cubit/pro_deal_closer_cubit.dart';
import 'package:get_it/get_it.dart';

/// Feature-local dependency registration for `pro_deal_closer`.
/// Called from core/di/injection_container.dart after core services
/// ([ConversationsApi], [ConversationsStream], [ConversationRepository]) are registered.
void registerProDealCloserDependencies(GetIt sl) {
  sl
    ..registerLazySingleton<ProDealCloserRepository>(
      () => ProDealCloserRepositoryImpl(
        api: sl<ConversationsApi>(),
        stream: sl<ConversationsStream>(),
        auth: sl<AuthService>(),
        profile: sl<UserProfileService>(),
        encoder: sl<ScreenshotEncoder>(),
        logger: sl<AppLogger>(),
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
