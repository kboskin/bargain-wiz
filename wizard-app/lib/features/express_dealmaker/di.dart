import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:appwizard/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:appwizard/features/express_dealmaker/domain/repositories/express_dealmaker_repository.dart';
import 'package:appwizard/features/express_dealmaker/presentation/cubit/express_dealmaker_cubit.dart';

/// Feature-local dependency registration for `express_dealmaker`.
/// Called from core/di/injection_container.dart. The datasource, mappers and
/// repository are registered in core DI; this adds the presentation cubit.
///
/// Resolve with `sl<ExpressDealmakerCubit>(param1: ExpressDealmakerCubitParams(...))`.
void registerExpressDealmakerDependencies(final GetIt sl) {
  sl.registerFactoryParam<ExpressDealmakerCubit, ExpressDealmakerCubitParams, void>(
    (final params, _) => ExpressDealmakerCubit(
      repository: sl<ExpressDealmakerRepository>(),
      conversationRepository: sl<ConversationRepository>(),
      prefs: sl.isRegistered<SharedPreferences>() ? sl<SharedPreferences>() : null,
      vibeId: params.vibeId,
      locale: params.locale,
      marketplace: params.marketplace,
    ),
  );
}
