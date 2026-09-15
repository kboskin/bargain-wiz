import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/pro_deal_closer/domain/entities/wizard_reply.dart';
import 'package:dartz/dartz.dart';

/// Pro Deal Closer backend: one conversational reply per user message and,
/// on demand, three intent-tagged copyable lines for a given reply.
abstract class ProDealCloserRepository {
  /// Wizard reply to the latest user message in [history] (oldest first),
  /// written in [vibe] ("friendly" | "no_nonsense" | "tactical" | "quiet_closer").
  /// [regenerate] is true for "Redo" of an existing reply.
  Future<Either<Failure, WizardReply>> getReply({
    required List<ProDealCloserMessage> history,
    required String vibe,
    required String locale,
    bool regenerate = false,
  });

  /// Three lines (opener / counter / close, each with an optional `why`)
  /// for the last wizard reply in [history].
  Future<Either<Failure, List<DealLine>>> getOptions({
    required List<ProDealCloserMessage> history,
    required String vibe,
    required String locale,
  });
}
