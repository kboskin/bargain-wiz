import 'package:flutter_test/flutter_test.dart';

import 'package:appwizard/features/express_dealmaker/data/datasources/express_dealmaker_remote_datasource.dart';

void main() {
  group('MockExpressDealmakerRemoteDataSource.buildReply', () {
    test('returns the vibe-specific set with intents and why', () {
      final reply = MockExpressDealmakerRemoteDataSource.buildReply(vibe: 'tactical');
      expect(reply.lines, hasLength(3));
      expect(reply.lines.map((final l) => l.intent), ['opener', 'counter', 'close']);
      expect(reply.lines.first.text, startsWith('Two identical Kallax units'));
      expect(reply.lines.every((final l) => (l.why ?? '').isNotEmpty), isTrue);
    });

    test('has a distinct set for each of the four vibes', () {
      final openers = ['friendly', 'no_nonsense', 'tactical', 'quiet_closer']
          .map((final v) => MockExpressDealmakerRemoteDataSource.buildReply(vibe: v).lines.first.text)
          .toSet();
      expect(openers, hasLength(4));
    });

    test('falls back to friendly for unknown or missing vibes', () {
      final friendly = MockExpressDealmakerRemoteDataSource.replySets['friendly']!;
      expect(MockExpressDealmakerRemoteDataSource.buildReply(vibe: 'zen').lines, friendly);
      expect(MockExpressDealmakerRemoteDataSource.buildReply().lines, friendly);
    });

    test('seeing line appends the keyword in parentheses when provided', () {
      expect(
        MockExpressDealmakerRemoteDataSource.buildReply().seeing,
        MockExpressDealmakerRemoteDataSource.seeing,
      );
      expect(
        MockExpressDealmakerRemoteDataSource.buildReply(keyword: ' pickup today ').seeing,
        '${MockExpressDealmakerRemoteDataSource.seeing} (pickup today)',
      );
      expect(
        MockExpressDealmakerRemoteDataSource.buildReply(keyword: '   ').seeing,
        MockExpressDealmakerRemoteDataSource.seeing,
      );
    });

    test('keyword "fail" is a QA hook that throws', () {
      expect(
        () => MockExpressDealmakerRemoteDataSource.buildReply(keyword: 'fail'),
        throwsStateError,
      );
      expect(
        () => MockExpressDealmakerRemoteDataSource.buildReply(keyword: ' FAIL '),
        throwsStateError,
      );
    });
  });
}
