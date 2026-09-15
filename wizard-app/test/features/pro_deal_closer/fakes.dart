import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:appwizard/features/pro_deal_closer/domain/entities/wizard_reply.dart';
import 'package:appwizard/features/pro_deal_closer/domain/repositories/pro_deal_closer_repository.dart';
import 'package:dartz/dartz.dart';

/// Recorded `getReply` call.
class ReplyCall {
  const ReplyCall({required this.history, required this.vibe, required this.regenerate});

  final List<ProDealCloserMessage> history;
  final String vibe;
  final bool regenerate;
}

/// In-memory Pro repository: replies "Reply for {vibe}" (+ " (Regenerated)"),
/// three fixed options; set [failure] to make every call fail.
class FakeProDealCloserRepository implements ProDealCloserRepository {
  final List<ReplyCall> replyCalls = [];
  final List<List<ProDealCloserMessage>> optionsCalls = [];
  Failure? failure;

  static const List<DealLine> options = [
    DealLine(text: 'Opener line', intent: DealIntent.opener, why: 'why 1'),
    DealLine(text: 'Counter line', intent: DealIntent.counter, why: 'why 2'),
    DealLine(text: 'Close line', intent: DealIntent.close, why: 'why 3'),
  ];

  @override
  Future<Either<Failure, WizardReply>> getReply({
    required List<ProDealCloserMessage> history,
    required String vibe,
    required String locale,
    bool regenerate = false,
  }) async {
    replyCalls.add(ReplyCall(history: history, vibe: vibe, regenerate: regenerate));
    final f = failure;
    if (f != null) return Left(f);
    return Right(WizardReply(text: 'Reply for $vibe${regenerate ? ' (Regenerated)' : ''}'));
  }

  @override
  Future<Either<Failure, List<DealLine>>> getOptions({
    required List<ProDealCloserMessage> history,
    required String vibe,
    required String locale,
  }) async {
    optionsCalls.add(history);
    final f = failure;
    if (f != null) return Left(f);
    return const Right(options);
  }
}

/// In-memory conversation store.
class FakeConversationRepository implements ConversationRepository {
  final Map<String, Conversation> store = {};
  Failure? failure;

  @override
  Future<Either<Failure, List<Conversation>>> getConversations() async {
    final f = failure;
    if (f != null) return Left(f);
    return Right(store.values.toList());
  }

  @override
  Future<Either<Failure, void>> saveConversation(Conversation conversation) async {
    final f = failure;
    if (f != null) return Left(f);
    store[conversation.id] = conversation;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteConversation(String id) async {
    store.remove(id);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> clearAll() async {
    store.clear();
    return const Right(null);
  }
}

AppLogger testLogger() => AppLogger(null);
