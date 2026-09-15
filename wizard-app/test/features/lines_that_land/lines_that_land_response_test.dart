import 'package:appwizard/features/lines_that_land/data/models/lines_that_land_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LinesThatLandResponse.fromJson', () {
    test('parses the function payload with multilocale texts', () {
      final r = LinesThatLandResponse.fromJson({
        'categories': [
          {
            'id': 'opening',
            'name': {'en': 'Opening lines', 'es': 'Frases de apertura'},
            'tips': [
              {'en': 'Any flex on price?', 'es': '¿Hay margen en el precio?'},
              'Plain English line',
            ],
          },
        ],
        'locales': ['en', 'es'],
        'updated_at': '2026-09-12T10:00:00Z',
        'refresh_interval_hours': 6,
        'source': 'remote_config',
      });
      final c = r.categories.single;
      expect(c.id, 'opening');
      expect(c.name.toJson(), {'en': 'Opening lines', 'es': 'Frases de apertura'});
      expect(c.tips.map((t) => t.toJson()), [
        {'en': 'Any flex on price?', 'es': '¿Hay margen en el precio?'},
        'Plain English line',
      ]);
      expect(r.locales, ['en', 'es']);
      expect(r.updatedAt, DateTime.utc(2026, 9, 12, 10));
      expect(r.refreshInterval, const Duration(hours: 6));
      expect(r.source, 'remote_config');
    });

    test('applies defaults for missing or invalid fields', () {
      final r = LinesThatLandResponse.fromJson({'categories': [], 'updated_at': 'nope', 'refresh_interval_hours': -1});
      expect(r.categories, isEmpty);
      expect(r.locales, isEmpty);
      expect(r.updatedAt, isNull);
      expect(r.refreshInterval, const Duration(hours: LinesThatLandResponse.defaultRefreshIntervalHours));
      expect(r.source, 'unknown');
    });

    test('round-trips through JSON (cache format)', () {
      final original = LinesThatLandResponse.fromJson({
        'categories': [
          {'id': 'closing', 'name': {'en': 'Closing', 'es': 'Cierre'}, 'tips': [{'en': 'Done.', 'es': 'Hecho.'}]},
        ],
        'locales': ['en', 'es'],
        'updated_at': '2026-09-12T10:00:00Z',
        'refresh_interval_hours': 24,
        'source': 'fallback',
      });
      final copy = LinesThatLandResponse.fromJson(original.toJson());
      expect(copy.toJson(), original.toJson());
      expect(copy.categories.single.tips.single.toJson(), {'en': 'Done.', 'es': 'Hecho.'});
    });
  });
}
