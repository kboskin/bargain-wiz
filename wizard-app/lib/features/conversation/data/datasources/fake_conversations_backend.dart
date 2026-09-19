import 'dart:async';

import 'package:appwizard/features/profile/domain/profile_fields.dart';
import 'package:appwizard/features/conversation/data/datasources/conversations_api.dart';
import 'package:appwizard/features/conversation/data/datasources/conversations_stream.dart';
import 'package:appwizard/features/conversation/data/models/conversation_api_models.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/shared/data/models/ai/ai_api_models.dart';

/// In-memory stand-in for the `conversations` function **and** its Firestore listeners
/// (`--dart-define=MOCK_AI=true`, widget work, tests).
///
/// Mirrors the server: every write returns ids straight away, and the "queued" model call
/// lands later — the canned reply after [replyDelay], options after [optionsDelay] with
/// `pendingOptions` set meanwhile. "Redo" regenerates in place.
class FakeConversationsBackend implements ConversationsApi, ConversationsStream {
  FakeConversationsBackend({
    this.replyDelay = const Duration(milliseconds: 1300),
    this.optionsDelay = const Duration(milliseconds: 800),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration replyDelay;
  final Duration optionsDelay;
  final DateTime Function() _clock;

  final Map<String, Conversation> _conversations = {};
  final Set<String> _archived = {};
  final Map<String, List<ProDealCloserMessage>> _messages = {};
  final StreamController<List<Conversation>> _listChanges = StreamController.broadcast();
  final Map<String, StreamController<List<ProDealCloserMessage>>> _messageChanges = {};
  int _ids = 0;

  static const String defaultVibe = 'friendly';
  static const String regeneratedSuffix = ' (Regenerated)';
  static const String seeing = r'IKEA Kallax shelf · $180 · listed 9 days · "slight scuff"';

  /// Reply paragraphs per vibe, verbatim from the design prototype.
  static const Map<String, String> replyTexts = {
    'friendly':
        "Nice find. Sellers usually list 15–25% above what they'll take, so a friendly \$140 with same-day pickup is a strong open. Want me to write it?",
    'no_nonsense':
        "Open at \$140 cash, pickup today. Don't explain, don't apologize. If they push back, hold at \$160 max.",
    'tactical':
        'Comparable Kallax units went for \$130–150 this week. Anchor at \$140 with that data, then trade a fast pickup for a \$160 ceiling.',
    'quiet_closer':
        "Keep it warm and low pressure: ask if they'd consider \$140 and offer flexible pickup. Most sellers meet you partway without any friction.",
  };

  /// Option / express line sets per vibe, verbatim from the prototype `REPLY_SETS`.
  static const Map<String, List<DealLine>> lineSets = {
    'friendly': [
      DealLine(intent: DealIntent.opener, text: 'Hi! Is the Kallax still available? I could pick it up today if \$140 works for you.', why: 'Warm open, signals a fast easy sale, anchors 22% under ask.'),
      DealLine(intent: DealIntent.counter, text: 'Totally understand. Could you do \$160 if I bring cash tonight and handle the loading?', why: 'Concedes a little while adding certainty and effort on your side.'),
      DealLine(intent: DealIntent.close, text: '\$160 sounds good — what time works for pickup today?', why: 'Assumes the yes and moves straight to logistics.'),
    ],
    'no_nonsense': [
      DealLine(intent: DealIntent.opener, text: 'Still available? \$140 cash, pickup today.', why: 'Short and decisive. Sellers on Marketplace respond to speed.'),
      DealLine(intent: DealIntent.counter, text: '\$160 is my max. I can be there in an hour.', why: "A firm ceiling plus immediacy removes the seller's reason to wait."),
      DealLine(intent: DealIntent.close, text: 'Deal at \$160. Send the address.', why: 'Closes without reopening price.'),
    ],
    'tactical': [
      DealLine(intent: DealIntent.opener, text: 'Two identical Kallax units sold this week for \$130–150 in this area. Would you take \$140?', why: 'Anchors with comparable data rather than opinion.'),
      DealLine(intent: DealIntent.counter, text: 'Given the scuff on the corner and the retail price is \$179 new, \$160 is fair for both of us.', why: 'Names a flaw and the new price to frame the counter as reasonable.'),
      DealLine(intent: DealIntent.close, text: "Let's lock in \$160. I'll bring exact cash and pick up at your convenience.", why: 'Removes friction and rewards the agreement.'),
    ],
    'quiet_closer': [
      DealLine(intent: DealIntent.opener, text: 'Lovely shelf. Would you consider \$140? Happy to pick up whenever suits.', why: 'Low pressure, keeps rapport, still anchors low.'),
      DealLine(intent: DealIntent.counter, text: "I hear you. If \$160 works, I'm ready whenever you are.", why: 'Soft counter that leaves the seller in control of timing.'),
      DealLine(intent: DealIntent.close, text: "Great, \$160 it is. Thank you — I'll message when I'm on my way.", why: 'Gracious close that reduces the chance of a back-out.'),
    ],
  };

  /// The tone the request asks for; the fake stands in for the prompt builder, so it reads
  /// the one field it needs out of the profile it was sent.
  static String _vibeOf(ConversationProfile profile) =>
      profile[ProfileFields.vibeKey]?.toString() ?? defaultVibe;

  static String replyFor(String vibe) => replyTexts[vibe] ?? replyTexts[defaultVibe]!;
  static List<DealLine> linesFor(String vibe) => lineSets[vibe] ?? lineSets[defaultVibe]!;

  /// Active conversations, for tests.
  List<Conversation> get conversations => List.unmodifiable(_conversations.values.where((c) => !_archived.contains(c.id)));

  /// Archived (soft-deleted) conversation ids, for tests.
  Set<String> get archived => Set.unmodifiable(_archived);
  List<ProDealCloserMessage> messagesOf(String conversationId) => List.unmodifiable(_messages[conversationId] ?? const []);

  // ── ConversationsStream ──────────────────────────────────────────────────

  @override
  Stream<List<Conversation>> watchConversations(String uid) async* {
    yield _sorted();
    yield* _listChanges.stream;
  }

  @override
  Stream<Conversation?> watchConversation(String uid, String conversationId) =>
      watchConversations(uid).map((list) => list.where((c) => c.id == conversationId).firstOrNull);

  @override
  Stream<List<ProDealCloserMessage>> watchMessages(String uid, String conversationId) async* {
    yield List.of(_messages[conversationId] ?? const []);
    yield* _messageController(conversationId).stream;
  }

  // ── ConversationsApi ─────────────────────────────────────────────────────

  @override
  Future<ConversationWriteResponse> create(CreateConversationRequest request) async {
    final id = 'fake_c${++_ids}';
    final now = _clock();
    final isExpress = request.type == 'express';
    _conversations[id] = Conversation(
      id: id,
      type: isExpress ? ConversationType.express : ConversationType.proDealCloser,
      createdAt: now,
      updatedAt: now,
      vibe: _vibeOf(request.profile),
      marketplace: request.profile[ProfileFields.marketplaceKey]?.toString(),
      keyword: request.keyword,
      title: isExpress ? null : _title(request.text, request.images),
    );
    _emitList();
    return _turn(id, request.text, request.images ?? const [], _vibeOf(request.profile),
        express: isExpress, keyword: request.keyword);
  }

  @override
  Future<ConversationWriteResponse> send(String conversationId, SendMessageRequest request) {
    _require(conversationId);
    return _turn(conversationId, request.text, request.images ?? const [], _vibeOf(request.profile));
  }

  @override
  Future<ConversationWriteResponse> requestOptions(String conversationId, ConversationActionRequest request) async {
    final target = _targetWizard(conversationId, request.messageId);
    _replace(conversationId, target.copyWith(pendingOptions: true));
    unawaited(Future<void>.delayed(optionsDelay).then((_) {
      final current = _messages[conversationId]?.where((m) => m.id == target.id).firstOrNull;
      if (current == null) return;
      _replace(conversationId, current.copyWith(options: linesFor(_vibeOf(request.profile)), pendingOptions: false));
    }));
    return ConversationWriteResponse(conversationId: conversationId, messageId: target.id);
  }

  @override
  Future<ConversationWriteResponse> redo(String conversationId, ConversationActionRequest request) async {
    final conversation = _require(conversationId);
    final target = _targetWizard(conversationId, request.messageId);
    final isExpress = conversation.type == ConversationType.express;
    _replace(conversationId, target.copyWith(status: MessageStatus.pending, options: const []));
    _update(conversation.copyWith(isTyping: true, vibe: _vibeOf(request.profile), keyword: request.keyword ?? conversation.keyword));
    unawaited(Future<void>.delayed(replyDelay).then((_) {
      final lines = linesFor(_vibeOf(request.profile));
      final text = isExpress ? seeing : '${replyFor(_vibeOf(request.profile))}$regeneratedSuffix';
      _replace(
        conversationId,
        target.copyWith(
          text: text,
          status: MessageStatus.done,
          revision: target.revision + 1,
          options: isExpress ? lines : const [],
        ),
      );
      _update(_require(conversationId).copyWith(
        isTyping: false,
        preview: isExpress ? lines.first.text : text,
        replyLines: isExpress ? lines : null,
        seeing: isExpress ? seeing : null,
      ));
    }));
    return ConversationWriteResponse(conversationId: conversationId, messageId: target.id, replyId: target.id);
  }

  @override
  Future<void> patch(String conversationId, ConversationPatchRequest request) async {
    final conversation = _require(conversationId);
    _update(conversation.copyWith(
      title: request.title,
      status: request.status == null ? null : ConversationStatus.fromString(request.status),
      priceBefore: request.priceBefore,
      priceAfter: request.priceAfter,
      vibe: request.vibe,
      marketplace: request.marketplace,
    ));
  }

  @override
  Future<void> archive(String conversationId) async {
    _require(conversationId);
    _archived.add(conversationId);
    _emitList();
  }

  // ── internals ────────────────────────────────────────────────────────────

  Future<ConversationWriteResponse> _turn(
    String conversationId,
    String? text,
    List<AiImagePayload> images,
    String vibe, {
    bool express = false,
    String? keyword,
  }) async {
    final list = _messages.putIfAbsent(conversationId, () => []);
    final seq = list.length;
    final userId = 'fake_m${++_ids}';
    final replyId = 'fake_m${++_ids}';
    list
      ..add(ProDealCloserMessage(
        id: userId,
        text: text ?? '',
        attachments: [for (var i = 0; i < images.length; i++) ChatAttachment(storagePath: 'fake/$conversationId/$userId-$i.jpg')],
        seq: seq + 1,
      ))
      ..add(ProDealCloserMessage(
        id: replyId,
        text: '',
        isWizard: true,
        status: MessageStatus.pending,
        seq: seq + 2,
      ));
    final conversation = _require(conversationId);
    _update(conversation.copyWith(
      isTyping: true,
      preview: text?.isNotEmpty == true ? text : 'Screenshot',
      messageCount: list.length,
      thumbnailStoragePath: conversation.thumbnailStoragePath ?? list.first.attachments.firstOrNull?.storagePath,
    ));
    _emitMessages(conversationId);

    // Like the backend: the model call is queued, so only ids come back now.
    unawaited(Future<void>.delayed(replyDelay).then((_) => express
        ? _complete(conversationId, replyId, seeing, options: linesFor(vibe), express: true, keyword: keyword)
        : _complete(conversationId, replyId, replyFor(vibe))));
    return ConversationWriteResponse(conversationId: conversationId, messageId: userId, replyId: replyId);
  }

  void _complete(String conversationId, String replyId, String text,
      {List<DealLine> options = const [], bool express = false, String? keyword}) {
    final conversation = _conversations[conversationId];
    final list = _messages[conversationId];
    if (conversation == null || list == null) return;
    final index = list.indexWhere((m) => m.id == replyId);
    if (index < 0) return;
    list[index] = list[index].copyWith(text: text, status: MessageStatus.done, options: options);
    _update(conversation.copyWith(
      isTyping: false,
      preview: express ? options.first.text : text,
      title: express ? seeing : conversation.title,
      replyLines: express ? options : null,
      seeing: express ? seeing : null,
      keyword: keyword,
      screenshotPaths: express ? [for (final a in list.first.attachments) a.storagePath] : null,
    ));
    _emitMessages(conversationId);
  }

  ProDealCloserMessage _targetWizard(String conversationId, String? messageId) {
    final list = _messages[conversationId] ?? const <ProDealCloserMessage>[];
    final wizards = list.where((m) => m.isWizard).toList();
    final target = messageId == null ? wizards.lastOrNull : wizards.where((m) => m.id == messageId).firstOrNull;
    if (target == null) throw StateError('Fake backend: no wizard message in $conversationId');
    return target;
  }

  void _replace(String conversationId, ProDealCloserMessage message) {
    final list = _messages[conversationId];
    if (list == null) return;
    final index = list.indexWhere((m) => m.id == message.id);
    if (index >= 0) list[index] = message;
    _emitMessages(conversationId);
  }

  Conversation _require(String conversationId) {
    final conversation = _conversations[conversationId];
    if (conversation == null) throw StateError('Fake backend: no conversation $conversationId');
    return conversation;
  }

  void _update(Conversation conversation) {
    _conversations[conversation.id] = conversation.copyWith(updatedAt: _clock());
    _emitList();
  }

  List<Conversation> _sorted() =>
      _conversations.values.where((c) => !_archived.contains(c.id)).toList()..sort((a, b) => b.sortedAt.compareTo(a.sortedAt));

  void _emitList() {
    if (_listChanges.hasListener) _listChanges.add(_sorted());
  }

  StreamController<List<ProDealCloserMessage>> _messageController(String conversationId) =>
      _messageChanges.putIfAbsent(conversationId, StreamController.broadcast);

  void _emitMessages(String conversationId) {
    final controller = _messageChanges[conversationId];
    if (controller != null && controller.hasListener) controller.add(List.of(_messages[conversationId] ?? const []));
  }

  static String? _title(String? text, List<AiImagePayload>? images) {
    final trimmed = text?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed.length > 60 ? '${trimmed.substring(0, 60).trimRight()}…' : trimmed;
    return (images?.isNotEmpty ?? false) ? 'Screenshot deal' : 'New deal';
  }
}
