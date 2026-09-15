import 'package:flutter_test/flutter_test.dart';

import 'package:appwizard/features/express_dealmaker/data/datasources/express_dealmaker_remote_datasource.dart';
import 'package:appwizard/features/express_dealmaker/data/mappers/express_dealmaker_mapper.dart';
import 'package:appwizard/features/express_dealmaker/domain/entities/deal_reply.dart';

void main() {
  group('DealReplyMapper', () {
    final mapper = DealReplyMapper();

    test('maps intent strings to DealIntent (case-insensitive, with aliases)', () {
      const dto = DealReplyDto(
        seeing: r'IKEA Kallax shelf · $180',
        lines: [
          DealLineDto(text: 'a', intent: 'opener', why: 'w1'),
          DealLineDto(text: 'b', intent: 'Counter'),
          DealLineDto(text: 'c', intent: 'CLOSE'),
          DealLineDto(text: 'd', intent: 'counter_offer'),
          DealLineDto(text: 'e', intent: 'something-else'),
          DealLineDto(text: 'f'),
        ],
      );

      final reply = mapper.toEntity(dto);

      expect(reply.seeing, r'IKEA Kallax shelf · $180');
      expect(reply.lines.map((final l) => l.intent), [
        DealIntent.opener,
        DealIntent.counter,
        DealIntent.close,
        DealIntent.counter,
        DealIntent.other,
        DealIntent.other,
      ]);
      expect(reply.lines.first.why, 'w1');
      expect(reply.lines[1].why, isNull);
      expect(reply.options, ['a', 'b', 'c', 'd', 'e', 'f']);
    });

    test('keeps text and why verbatim', () {
      final line = mapper.toLine(const DealLineDto(text: r'$160 works?', intent: 'close', why: 'Assumes the yes.'));
      expect(line, const DealLine(text: r'$160 works?', intent: DealIntent.close, why: 'Assumes the yes.'));
    });
  });

  test('UploadScreenshotResultMapper passes the id through', () {
    final mapper = UploadScreenshotResultMapper();
    expect(mapper.toEntity(const UploadScreenshotResultDto(id: 'abc')).id, 'abc');
    expect(mapper.toEntity(const UploadScreenshotResultDto()).id, isNull);
  });
}
