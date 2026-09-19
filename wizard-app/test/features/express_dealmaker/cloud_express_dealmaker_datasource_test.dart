import 'dart:async';
import 'dart:typed_data';

import 'package:appwizard/core/network/cloud_functions_client.dart';
import 'package:appwizard/core/services/auth_service.dart';
import 'package:appwizard/core/services/user_profile_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/core/utils/screenshot_encoder.dart';
import 'package:appwizard/features/conversation/data/datasources/conversations_api.dart';
import 'package:appwizard/features/conversation/data/datasources/conversations_stream.dart';
import 'package:appwizard/features/conversation/data/models/conversation_api_models.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/express_dealmaker/data/datasources/cloud_express_dealmaker_remote_datasource.dart';
import 'package:appwizard/features/express_dealmaker/data/datasources/express_dealmaker_remote_datasource.dart';
import 'package:appwizard/features/profile/domain/profile_fields.dart';
import 'package:flutter_test/flutter_test.dart';

class _SilentLogger implements AppLogger {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeProfile implements UserProfileService {
  /// What the configured screens collect, keyed as they are sent.
  static const _stored = <String, dynamic>{
    ProfileFields.vibeKey: 'friendly',
    ProfileFields.pushKey: 40,
    ProfileFields.marketplaceKey: 'facebook',
    'deal_size': 50,
    'deals_per_month': '3_5',
    'hurdles': ['being_rude'],
    ProfileFields.referralKey: 'FRIEND-42',
  };

  @override
  Map<String, dynamic> payload({
    Map<String, dynamic> overrides = const {},
    Set<String> except = const {},
  }) =>
      {
        for (final e in _stored.entries)
          if (!except.contains(e.key)) e.key: overrides[e.key] ?? e.value,
      };

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeAuth implements AuthService {
  @override
  Future<String?> ensureUid() async => 'u1';
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeEncoder extends ScreenshotEncoder {
  const _FakeEncoder();
  @override
  Future<EncodedImage> encode(String path) async =>
      EncodedImage(mimeType: 'image/jpeg', bytes: Uint8List.fromList(path.codeUnits));
}

/// Emits what the backend's worker would write to the conversation document.
class _FakeStream implements ConversationsStream {
  final _controller = StreamController<Conversation?>.broadcast();

  void emit(Conversation? conversation) => _controller.add(conversation);

  @override
  Stream<Conversation?> watchConversation(String uid, String conversationId) => _controller.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeApi implements ConversationsApi {
  CreateConversationRequest? created;
  int creates = 0;
  String? redoneConversation;
  ConversationActionRequest? redone;
  /// What `redo` throws instead of accepting the turn.
  CloudFunctionException? redoError;

  @override
  Future<ConversationWriteResponse> create(CreateConversationRequest request) async {
    created = request;
    creates++;
    return const ConversationWriteResponse(conversationId: 'c1', messageId: 'm1', replyId: 'm2');
  }

  @override
  Future<ConversationWriteResponse> redo(String conversationId, ConversationActionRequest request) async {
    redoneConversation = conversationId;
    redone = request;
    final error = redoError;
    if (error != null) throw error;
    return const ConversationWriteResponse(conversationId: 'c1', messageId: 'm2', replyId: 'm2');
  }

  @override
  Future<ConversationWriteResponse> send(String conversationId, SendMessageRequest request) => throw UnimplementedError();
  @override
  Future<ConversationWriteResponse> requestOptions(String conversationId, ConversationActionRequest request) =>
      throw UnimplementedError();
  @override
  Future<void> patch(String conversationId, ConversationPatchRequest request) => throw UnimplementedError();
  @override
  Future<void> archive(String conversationId) => throw UnimplementedError();
}

Conversation _result({
  bool typing = false,
  List<DealLine> lines = const [DealLine(text: r'Hi! $140 today?', intent: DealIntent.opener, why: 'Anchors low.')],
  String? seeing = r'IKEA Kallax · $180',
}) =>
    Conversation(
      id: 'c1',
      type: ConversationType.express,
      createdAt: DateTime(2026, 9, 18),
      replyLines: lines,
      seeing: seeing,
      isTyping: typing,
    );

void main() {
  late _FakeApi api;
  late _FakeStream stream;
  late CloudExpressDealmakerRemoteDataSource source;

  setUp(() {
    api = _FakeApi();
    stream = _FakeStream();
    source = CloudExpressDealmakerRemoteDataSource(
      api,
      stream,
      _FakeAuth(),
      _FakeProfile(),
      const _FakeEncoder(),
      _SilentLogger(),
      resultTimeout: const Duration(seconds: 2),
    );
  });

  test('first reply creates an express conversation and waits for the queued result', () async {
    final a = await source.uploadScreenshot('/tmp/a.jpg');
    final b = await source.uploadScreenshot('/tmp/b.jpg');

    final pending = source.getDealReply(uploadedIds: [a.id!, b.id!], locale: 'es', keyword: 'scuff', vibe: 'tactical');
    await pumpEventQueue();

    final body = api.created!.toJson();
    expect(body['type'], 'express');
    expect(body['keyword'], 'scuff');
    expect(body['vibe'], 'tactical');
    expect(body['push'], 40);
    expect(body['locale'], 'es');
    expect(body['deals_per_month'], '3_5');
    expect(body['hurdles'], ['being_rude']);
    expect(body.containsKey('referral_code'), isFalse); // the profile endpoint's business
    expect((body['images'] as List), hasLength(2));

    stream.emit(_result(typing: true)); // still working: not a result
    stream.emit(_result());

    final reply = await pending;
    expect(reply.conversationId, 'c1');
    expect(reply.seeing, r'IKEA Kallax · $180');
    expect(reply.lines.single.text, r'Hi! $140 today?');
  });

  test('follow-ups regenerate the existing conversation without re-sending screenshots', () async {
    final pending = source.getDealReply(
      uploadedIds: const ['whatever'],
      locale: 'en',
      keyword: 'pickup',
      vibe: 'friendly',
      conversationId: 'c1',
    );
    await pumpEventQueue();
    stream.emit(_result(lines: const [DealLine(text: 'Again', intent: DealIntent.close)]));

    final reply = await pending;
    expect(api.created, isNull);
    expect(api.redoneConversation, 'c1');
    expect(api.redone!.toJson()['keyword'], 'pickup');
    expect(reply.lines.single.text, 'Again');
  });

  test('a failed turn names the conversation, so a retry can regenerate it', () async {
    final a = await source.uploadScreenshot('/tmp/a.jpg');
    final pending = source.getDealReply(uploadedIds: [a.id!], locale: 'en');
    await pumpEventQueue();
    stream.emit(_result(lines: const [], seeing: null));

    await expectLater(
      pending,
      throwsA(isA<ExpressGenerationException>()
          .having((final e) => e.conversationId, 'conversationId', 'c1')
          .having((final e) => e.message, 'message', 'The wizard could not answer. Try again.')),
    );
    expect(api.creates, 1);
  });

  test('giving up on the wait still names the conversation', () async {
    source = CloudExpressDealmakerRemoteDataSource(
      api, stream, _FakeAuth(), _FakeProfile(), const _FakeEncoder(), _SilentLogger(),
      resultTimeout: const Duration(milliseconds: 10),
    );

    await expectLater(
      source.getDealReply(uploadedIds: const ['x'], locale: 'en', conversationId: 'c1'),
      throwsA(isA<ExpressGenerationException>().having((final e) => e.conversationId, 'conversationId', 'c1')),
    );
  });

  test('a retry while the wizard is still typing waits for that turn instead of queueing one',
      () async {
    api.redoError = const CloudFunctionException(
      CloudExpressDealmakerRemoteDataSource.turnInProgress,
      'The wizard is still typing',
      httpStatus: 409,
    );

    final pending = source.getDealReply(uploadedIds: const ['x'], locale: 'en', conversationId: 'c1');
    await pumpEventQueue();
    stream.emit(_result(lines: const [DealLine(text: 'Late but here', intent: DealIntent.close)]));

    final reply = await pending;
    expect(reply.lines.single.text, 'Late but here');
    expect(api.creates, 0, reason: 'the running turn was reused, not replaced');
  });

  test('any other error from a regeneration is not swallowed', () async {
    api.redoError = const CloudFunctionException('NOT_FOUND', 'No such conversation', httpStatus: 404);

    await expectLater(
      source.getDealReply(uploadedIds: const ['x'], locale: 'en', conversationId: 'c1'),
      throwsA(isA<CloudFunctionException>()),
    );
  });

  test('throws when nothing was prepared for a new deal', () async {
    await expectLater(source.getDealReply(uploadedIds: const ['nope'], locale: 'en'), throwsStateError);
    expect(api.created, isNull);
  });
}
