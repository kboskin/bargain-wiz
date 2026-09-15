import 'package:get_it/get_it.dart';

import 'package:appwizard/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:appwizard/features/history/presentation/cubit/history_cubit.dart';

/// Feature-local dependency registration for `history`.
/// Called from core/di/injection_container.dart.
void registerHistoryDependencies(GetIt sl) {
  sl.registerFactory<HistoryCubit>(
    () => HistoryCubit(sl<ConversationRepository>()),
  );
}
