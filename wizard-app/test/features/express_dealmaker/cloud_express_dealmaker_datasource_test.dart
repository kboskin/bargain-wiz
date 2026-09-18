import 'dart:typed_data';

import 'package:appwizard/core/services/user_profile_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/core/utils/screenshot_encoder.dart';
import 'package:appwizard/features/conversation/data/datasources/conversations_api.dart';
import 'package:appwizard/features/conversation/data/models/conversation_api_models.dart';
import 'package:appwizard/features/express_dealmaker/data/datasources/cloud_express_dealmaker_remote_datasource.dart';
import 'package:appwizard/features/shared/data/models/ai/ai_api_models.dart';
import 'package:flutter_test/flutter_test.dart';

class _SilentLogger implements AppLogger {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeProfile implements UserProfileService {
  @override
  String get vibeId => 'friendly';
  @override
  int get pushValue => 40;
  @override
  String? get marketplace => 'facebook';
  @override
  int get dealSizeValue => 50;
  @override
  String? get dealsPerMonth => '3_5';
  @override
  List<String> get hurdles => const ['being_rude'];
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeEncoder extends ScreenshotEncoder {
  const _FakeEncoder();
  @override
  Future<EncodedImage> encode(String path) async =>
      EncodedImage(mimeType: 'image/jpeg', bytes: Uint8List.fromList(path.codeUnits), width: 1, height: 1);
}

class _FakeApi implements ConversationsApi {
  CreateConversationRequest? created;
  String? redoneConversation;
  ConversationActionRequest? redone;

  @override
  Future<ConversationWriteResponse> create(CreateConversationRequest request) async {
    created = request;
    return const ConversationWriteResponse(
      conversationId: 'c1',
      messageId: 'm1',
      replyId: 'm2',
      express: ExpressResultPayload(
        seeing: r'IKEA Kallax · $180',
        lines: [
          AiDealLine(text: r'Hi! $140 today?', intent: 'opener', why: 'Anchors low.'),
          AiDealLine(text: '', intent: 'counter'),
        ],
      ),
    );
  }

  @override
  Future<ConversationWriteResponse> redo(String conversationId, ConversationActionRequest request) async {
    redoneConversation = conversationId;
    redone = request;
    return const ConversationWriteResponse(
      conversationId: 'c1',
      messageId: 'm2',
      express: ExpressResultPayload(seeing: 'Kallax', lines: [AiDealLine(text: 'Again', intent: 'close')]),
    );
  }

  @override
  Future<ConversationWriteResponse> send(String conversationId, SendMessageRequest request) =>
      throw UnimplementedError();
  @override
  Future<ConversationWriteResponse> requestOptions(String conversationId, ConversationActionRequest request) =>
      throw UnimplementedError();
  @override
  Future<void> patch(String conversationId, ConversationPatchRequest request) => throw UnimplementedError();
  @override
  Future<void> archive(String conversationId) => throw UnimplementedError();
}

void main() {
  late _FakeApi api;
  late CloudExpressDealmakerRemoteDataSource source;

  setUp(() {
    api = _FakeApi();
    source = CloudExpressDealmakerRemoteDataSource(
      api,
      _FakeProfile(),
      const _FakeEncoder(),
      _SilentLogger(),
      requestIdGenerator: () => 'req-1',
    );
  });

  test('first reply creates an express conversation with the prepared screenshots and the profile', () async {
    final a = await source.uploadScreenshot('/tmp/a.jpg');
    final b = await source.uploadScreenshot('/tmp/b.jpg');

    final reply = await source.getDealReply(
      uploadedIds: [a.id!, b.id!],
      locale: 'es',
      keyword: 'scuff',
      vibe: 'tactical',
    );

    final body = api.created!.toJson();
    expect(body['type'], 'express');
    expect(body['request_id'], 'req-1');
    expect(body['keyword'], 'scuff');
    expect(body['vibe'], 'tactical');
    expect(body['push'], 40);
    expect(body['locale'], 'es');
    expect(body['marketplace'], 'facebook');
    expect(body['deal_size'], 50);
    expect(body['deals_per_month'], '3_5');
    expect(body['hurdles'], ['being_rude']);
    final images = body['images'] as List;
    expect(images, hasLength(2));
    expect((images.first as Map)['mime_type'], 'image/jpeg');
    expect((images.first as Map)['data'], isNotEmpty);

    expect(reply.conversationId, 'c1');
    expect(reply.seeing, r'IKEA Kallax · $180');
    expect(reply.lines.map((l) => l.text), [r'Hi! $140 today?']); // empty line dropped
    expect(api.redone, isNull);
  });

  test('follow-ups regenerate the existing conversation without re-sending screenshots', () async {
    final reply = await source.getDealReply(
      uploadedIds: const ['whatever'],
      locale: 'en',
      keyword: 'pickup',
      vibe: 'friendly',
      conversationId: 'c1',
    );

    expect(api.created, isNull);
    expect(api.redoneConversation, 'c1');
    final body = api.redone!.toJson();
    expect(body['keyword'], 'pickup');
    expect(body['vibe'], 'friendly');
    expect(body.containsKey('message_id'), isFalse);
    expect(reply.conversationId, 'c1');
    expect(reply.lines.single.text, 'Again');
  });

  test('throws when nothing was prepared for a new deal', () async {
    expect(
      () => source.getDealReply(uploadedIds: const ['nope'], locale: 'en'),
      throwsStateError,
    );
    expect(api.created, isNull);
  });
}
