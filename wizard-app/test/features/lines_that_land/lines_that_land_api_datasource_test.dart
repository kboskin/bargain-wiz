import 'package:appwizard/core/network/cloud_functions_client.dart';
import 'package:appwizard/features/lines_that_land/data/datasources/lines_that_land_api_datasource.dart';
import 'package:appwizard/features/lines_that_land/data/models/lines_that_land_response.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApi implements CloudFunctionsApi {
  _FakeApi(this.payload);

  final Map<String, dynamic> payload;
  final paths = <String>[];

  @override
  Future<T> get<T>(String path, {required T Function(Map<String, dynamic> json) fromJson}) async {
    paths.add(path);
    return fromJson(payload);
  }
}

void main() {
  test('fetchFeed GETs /lines_that_land and decodes a LinesThatLandResponse', () async {
    final api = _FakeApi({
      'categories': [
        {
          'id': 'opening',
          'name': {'en': 'Opening lines', 'es': 'Frases de apertura'},
          'tips': [
            {'en': 'Any flex on price?', 'es': '¿Hay margen en el precio?'},
          ],
        },
      ],
      'locales': ['en', 'es'],
      'updated_at': '2026-09-12T10:00:00Z',
      'refresh_interval_hours': 24,
      'source': 'remote_config',
    });

    final response = await LinesThatLandApiDataSourceImpl(api).fetchFeed();

    expect(api.paths, ['/lines_that_land']);
    expect(response, isA<LinesThatLandResponse>());
    expect(response.categories.single.name.toJson(), {'en': 'Opening lines', 'es': 'Frases de apertura'});
    expect(response.locales, ['en', 'es']);
    expect(response.updatedAt, DateTime.utc(2026, 9, 12, 10));
    expect(response.source, 'remote_config');
  });
}
