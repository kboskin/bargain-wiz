import 'dart:typed_data';

import 'package:appwizard/core/network/cloud_functions_client.dart';
import 'package:appwizard/core/services/user_profile_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/core/utils/screenshot_encoder.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/pro_deal_closer/data/datasources/cloud_pro_deal_closer_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

class _SilentLogger implements AppLogger {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeProfile implements UserProfileService {
  @override
  int get pushValue => 40;
  @override
  String? get marketplace => 'facebook';
  @override
  int get dealSizeValue => 50;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeEncoder extends ScreenshotEncoder {
  const _FakeEncoder();
  @override
  Future<EncodedImage> encode(String path) async =>
      EncodedImage(mimeType: 'image/jpeg', bytes: Uint8List.fromList(path.codeUnits), width: 1, height: 1);
}

class _FakeApi implements CloudFunctionsApi {
  _FakeApi(this.response);
  final Map<String, dynamic> response;
  Map<String, dynamic>? lastBody;

  @override
  Future<T> get<T>(String path, {required T Function(Map<String, dynamic> json) fromJson}) =>
      throw UnimplementedError();

  @override
  Future<T> post<T>(String path, {required Map<String, dynamic> body, required T Function(Map<String, dynamic> json) fromJson}) async {
    expect(path, '/pro_deal_closer');
    lastBody = body;
    return fromJson(response);
  }
}

void main() {
  const history = [
    ProDealCloserMessage(text: 'Kallax listed at \$180', attachmentPaths: ['/s/1.png', '/s/2.png']),
    ProDealCloserMessage(text: 'Open at \$140.', isWizard: true),
    ProDealCloserMessage(text: 'They said \$170', attachmentPaths: ['/s/3.png']),
  ];

  test('getReply sends the transcript with images on user turns and the profile', () async {
    final api = _FakeApi({'reply': 'Hold at \$160 and offer pickup tonight.'});
    final ds = CloudProDealCloserRemoteDataSource(api, _FakeProfile(), const _FakeEncoder(), _SilentLogger());

    final reply = await ds.getReply(history: history, vibe: 'quiet_closer', locale: 'en', regenerate: true);

    expect(reply.text, 'Hold at \$160 and offer pickup tonight.');
    final body = api.lastBody!;
    expect(body['mode'], 'reply');
    expect(body['regenerate'], isTrue);
    expect(body['vibe'], 'quiet_closer');
    expect(body['push'], 40);
    expect(body['marketplace'], 'facebook');
    final messages = body['messages'] as List;
    expect(messages.map((m) => m['role']), ['user', 'wizard', 'user']);
    expect((messages[0]['images'] as List).length, 2);
    expect(messages[1].containsKey('images'), isFalse);
    expect((messages[2]['images'] as List).length, 1);
  });

  test('getOptions maps lines and drops empty ones', () async {
    final api = _FakeApi({
      'lines': [
        {'intent': 'opener', 'text': 'Hi!', 'why': 'warm'},
        {'intent': 'close', 'text': ''},
      ],
    });
    final ds = CloudProDealCloserRemoteDataSource(api, _FakeProfile(), const _FakeEncoder(), _SilentLogger());

    final options = await ds.getOptions(history: history, vibe: 'friendly', locale: 'es');

    expect(api.lastBody!['mode'], 'options');
    expect(api.lastBody!['locale'], 'es');
    expect(options.map((o) => o.text), ['Hi!']);
  });
}
