import 'dart:typed_data';

import 'package:appwizard/core/network/cloud_functions_client.dart';
import 'package:appwizard/core/services/user_profile_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/core/utils/screenshot_encoder.dart';
import 'package:appwizard/features/express_dealmaker/data/datasources/cloud_express_dealmaker_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

class _SilentLogger implements AppLogger {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeProfile implements UserProfileService {
  @override
  String get vibeId => 'tactical';
  @override
  int get pushValue => 80;
  @override
  String? get marketplace => 'ebay';
  @override
  int get dealSizeValue => 550;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeEncoder extends ScreenshotEncoder {
  const _FakeEncoder();
  @override
  Future<EncodedImage> encode(String path) async =>
      EncodedImage(mimeType: 'image/jpeg', bytes: Uint8List.fromList([1, 2, 3]), width: 10, height: 20);
}

class _FakeApi implements CloudFunctionsApi {
  _FakeApi(this.response);
  final Map<String, dynamic> response;
  String? lastPath;
  Map<String, dynamic>? lastBody;

  @override
  Future<T> get<T>(String path, {required T Function(Map<String, dynamic> json) fromJson}) =>
      throw UnimplementedError();

  @override
  Future<T> post<T>(String path, {required Map<String, dynamic> body, required T Function(Map<String, dynamic> json) fromJson}) async {
    lastPath = path;
    lastBody = body;
    return fromJson(response);
  }
}

void main() {
  final api = _FakeApi({
    'seeing': 'IKEA Kallax · \$180',
    'lines': [
      {'intent': 'opener', 'text': 'Still available? \$140 cash today.', 'why': 'Anchors low.'},
      {'intent': 'counter', 'text': '\$160 is my max.'},
      {'text': ''},
    ],
    'model': 'gemini-2.5-flash',
  });
  final ds = CloudExpressDealmakerRemoteDataSource(api, _FakeProfile(), const _FakeEncoder(), _SilentLogger());

  test('prepares screenshots on device and posts them with the buyer profile', () async {
    final a = await ds.uploadScreenshot('/tmp/a.png');
    final b = await ds.uploadScreenshot('/tmp/b.png');
    expect([a.id, b.id], ['shot_1', 'shot_2']);

    final reply = await ds.getDealReply(uploadedIds: [a.id!, b.id!], locale: 'es', keyword: 'scuff');

    expect(api.lastPath, '/express_dealmaker');
    final body = api.lastBody!;
    expect((body['images'] as List).length, 2);
    expect((body['images'] as List).first, {'mime_type': 'image/jpeg', 'data': 'AQID'});
    expect(body['keyword'], 'scuff');
    expect(body['locale'], 'es');
    expect(body['vibe'], 'tactical'); // falls back to the profile vibe
    expect(body['push'], 80);
    expect(body['marketplace'], 'ebay');
    expect(body['deal_size'], 550);
    expect(body.containsKey('text'), isFalse);

    expect(reply.seeing, 'IKEA Kallax · \$180');
    expect(reply.lines.map((l) => l.intent), ['opener', 'counter']); // empty line dropped
    expect(reply.lines.first.why, 'Anchors low.');
  });

  test('an explicit vibe wins over the profile', () async {
    final a = await ds.uploadScreenshot('/tmp/c.png');
    await ds.getDealReply(uploadedIds: [a.id!], locale: 'en', vibe: 'friendly');
    expect(api.lastBody!['vibe'], 'friendly');
  });

  test('fails clearly when no prepared screenshot matches', () async {
    expect(ds.getDealReply(uploadedIds: ['nope'], locale: 'en'), throwsStateError);
  });
}
