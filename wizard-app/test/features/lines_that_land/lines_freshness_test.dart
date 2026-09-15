import 'package:appwizard/features/lines_that_land/presentation/utils/lines_freshness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 12, 12);

  group('LinesFreshness.describe', () {
    test('today / yesterday / dated, with the endpoint cadence', () {
      expect(
        LinesFreshness.describe(now: now, updatedAt: DateTime(2026, 9, 12, 8), refreshInterval: const Duration(hours: 24)),
        'Updated today · new lines every day',
      );
      expect(
        LinesFreshness.describe(now: now, updatedAt: DateTime(2026, 9, 11, 23), refreshInterval: const Duration(days: 1)),
        'Updated yesterday · new lines every day',
      );
      expect(
        LinesFreshness.describe(now: now, updatedAt: DateTime(2026, 9, 1), refreshInterval: const Duration(days: 7)),
        'Updated Sep 1 · new lines every week',
      );
    });

    test('without an update time only the cadence is shown', () {
      expect(LinesFreshness.describe(now: now, refreshInterval: const Duration(hours: 6)), 'New lines every 6 hours');
      expect(LinesFreshness.describe(now: now), 'New lines every day');
    });
  });

  test('LinesFreshness.cadenceOf', () {
    expect(LinesFreshness.cadenceOf(const Duration(hours: 1)), 'every hour');
    expect(LinesFreshness.cadenceOf(const Duration(minutes: 30)), 'every hour');
    expect(LinesFreshness.cadenceOf(const Duration(days: 3)), 'every 3 days');
    expect(LinesFreshness.cadenceOf(const Duration(days: 14)), 'every 2 weeks');
    expect(LinesFreshness.cadenceOf(Duration.zero), 'every day');
    expect(LinesFreshness.cadenceOf(null), 'every day');
  });
}
