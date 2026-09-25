import 'package:appwizard/core/services/auth_service.dart';
import 'package:appwizard/core/services/user_profile_service.dart';
import 'package:appwizard/core/utils/screenshot_encoder.dart';
import 'package:appwizard/features/conversation/data/models/conversation_api_models.dart';
import 'package:appwizard/features/pro_deal_closer/data/repositories/pro_deal_closer_repository_impl.dart';
import 'package:appwizard/features/profile/domain/profile_fields.dart';
import 'package:flutter_test/flutter_test.dart';

import '../conversation/fake_conversations_backend.dart';
import 'fakes.dart';

/// Records what the repository sends, and answers like the real function.
class _RecordingBackend extends FakeConversationsBackend {
  _RecordingBackend() : super(replyDelay: Duration.zero, optionsDelay: Duration.zero);

  final List<CreateConversationRequest> creates = [];
  final List<SendMessageRequest> sends = [];

  @override
  Future<ConversationWriteResponse> create(final CreateConversationRequest request) {
    creates.add(request);
    return super.create(request);
  }

  @override
  Future<ConversationWriteResponse> send(final String conversationId, final SendMessageRequest request) {
    sends.add(request);
    return super.send(conversationId, request);
  }
}

class _Profile implements UserProfileService {
  @override
  ProfileSnapshot snapshot({
    final Map<String, dynamic> overrides = const {},
    final Set<String> except = const {},
  }) =>
      const ProfileSnapshot({}, []);

  @override
  dynamic noSuchMethod(final Invocation invocation) => null;
}

class _Auth implements AuthService {
  @override
  dynamic noSuchMethod(final Invocation invocation) => null;
}

void main() {
  late _RecordingBackend backend;
  late ProDealCloserRepositoryImpl repository;

  setUp(() {
    backend = _RecordingBackend();
    repository = ProDealCloserRepositoryImpl(
      api: backend,
      stream: backend,
      auth: _Auth(),
      profile: _Profile(),
      encoder: const ScreenshotEncoder(),
      logger: testLogger(),
    );
  });

  test('the objective goes out once, as text, with the create, and never again', () async {
    final created = await repository.send(
      text: 'They ask 180',
      overrides: const {},
      locale: 'en',
      objective: 'Objective: get a discount.',
    );
    final cid = created.getOrElse(() => throw StateError('send failed')).conversationId;
    await repository.send(
      conversationId: cid,
      text: 'He said 170',
      overrides: const {},
      locale: 'en',
      objective: 'Objective: get a discount.',
    );

    expect(backend.creates.single.toJson()['objective'], 'Objective: get a discount.');
    expect(backend.sends.single.toJson().containsKey('objective'), isFalse);
  });

  test('none picked, none sent', () async {
    await repository.send(text: 'a', overrides: const {}, locale: 'en');

    expect(backend.creates.single.toJson().containsKey('objective'), isFalse);
  });
}
