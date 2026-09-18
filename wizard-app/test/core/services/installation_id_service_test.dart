import 'dart:math';

import 'package:appwizard/core/config/prefs_keys.dart';
import 'package:appwizard/core/services/installation_id_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final uuidV4 = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

  test('mints a v4 UUID once and keeps it', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = InstallationIdService(prefs, random: Random(7));

    final first = service.id;
    expect(first, matches(uuidV4));
    expect(service.id, first);
    expect(prefs.getString(PrefsKeys.installationId), first);
    expect(InstallationIdService(prefs).id, first); // survives a new instance
  });

  test('reuses an id already in preferences', () async {
    SharedPreferences.setMockInitialValues({PrefsKeys.installationId: '3fa85f64-5717-4562-b3fc-2c963f66afa6'});
    final prefs = await SharedPreferences.getInstance();
    expect(InstallationIdService(prefs).id, '3fa85f64-5717-4562-b3fc-2c963f66afa6');
  });
}
