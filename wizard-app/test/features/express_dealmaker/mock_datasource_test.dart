import 'package:flutter_test/flutter_test.dart';

import 'package:appwizard/features/express_dealmaker/data/datasources/express_dealmaker_remote_datasource.dart';

void main() {
  group('MockExpressDealmakerRemoteDataSource.buildReply', () {
    test('every canned set has three lines with intents and a why', () {
      for (var i = 0; i < MockExpressDealmakerRemoteDataSource.replySets.length; i++) {
        final reply = MockExpressDealmakerRemoteDataSource.buildReply(set: i);
        expect(reply.lines, hasLength(3));
        expect(reply.lines.map((final l) => l.intent), ['opener', 'counter', 'close']);
        expect(reply.lines.every((final l) => (l.why ?? '').isNotEmpty), isTrue);
      }
    });

    test('consecutive sets differ, so a re-request visibly changes the result', () {
      final openers = List.generate(
        MockExpressDealmakerRemoteDataSource.replySets.length,
        (final i) => MockExpressDealmakerRemoteDataSource.buildReply(set: i).lines.first.text,
      ).toSet();
      expect(openers, hasLength(MockExpressDealmakerRemoteDataSource.replySets.length));
    });

    test('the set index wraps, so no call can land out of range', () {
      final first = MockExpressDealmakerRemoteDataSource.replySets.first;
      expect(MockExpressDealmakerRemoteDataSource.buildReply().lines, first);
      expect(
        MockExpressDealmakerRemoteDataSource.buildReply(
          set: MockExpressDealmakerRemoteDataSource.replySets.length,
        ).lines,
        first,
      );
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
