import 'package:flutter_test/flutter_test.dart';

import 'package:appwizard/features/express_dealmaker/domain/utils/deal_title.dart';

void main() {
  group('DealTitle.fromSeeing', () {
    test('takes the segment before the first "·"', () {
      expect(
        DealTitle.fromSeeing(r'IKEA Kallax shelf · $180 · listed 9 days · "slight scuff"'),
        'IKEA Kallax shelf',
      );
    });

    test('uses the whole string when there is no separator', () {
      expect(DealTitle.fromSeeing('Road bike, 56cm'), 'Road bike, 56cm');
    });

    test('falls back to "Untitled deal" for null / empty / separator-only input', () {
      expect(DealTitle.fromSeeing(null), DealTitle.untitled);
      expect(DealTitle.fromSeeing(''), DealTitle.untitled);
      expect(DealTitle.fromSeeing('   '), DealTitle.untitled);
      expect(DealTitle.fromSeeing(r' · $180'), DealTitle.untitled);
      expect(DealTitle.fromSeeing(null, fallback: 'Sin título'), 'Sin título');
    });

    test('truncates long titles to ~40 chars with an ellipsis', () {
      const long = r'A very long listing title for a mid-century modern teak sideboard · $900';
      final title = DealTitle.fromSeeing(long);
      expect(title.length, lessThanOrEqualTo(DealTitle.maxLength));
      expect(title, endsWith('…'));
      expect(title, startsWith('A very long listing title'));
    });

    test('keeps a title of exactly 40 chars intact', () {
      final exact = 'x' * DealTitle.maxLength;
      expect(DealTitle.fromSeeing('$exact · \$1'), exact);
    });
  });
}
