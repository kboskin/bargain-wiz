import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:appwizard/core/config/prefs_keys.dart';
import 'package:appwizard/features/lines_that_land/data/models/lines_that_land_response.dart';

/// A cached function response and when it was fetched.
class CachedLinesFeed {
  const CachedLinesFeed(this.response, this.fetchedAt);

  final LinesThatLandResponse response;
  final DateTime fetchedAt;

  /// Fresh while younger than the cadence the function declared.
  bool isFresh(DateTime now) => now.difference(fetchedAt) < response.refreshInterval;
}

/// On-device cache of the last `lines_that_land` response.
abstract class LinesThatLandLocalCache {
  CachedLinesFeed? read();
  Future<void> write(LinesThatLandResponse response, DateTime fetchedAt);
}

class LinesThatLandLocalCacheImpl implements LinesThatLandLocalCache {
  LinesThatLandLocalCacheImpl(this._prefs);

  final SharedPreferences _prefs;

  @override
  CachedLinesFeed? read() {
    final raw = _prefs.getString(PrefsKeys.linesThatLandCache);
    final at = _prefs.getString(PrefsKeys.linesThatLandFetchedAt);
    if (raw == null || at == null) return null;
    try {
      final decoded = jsonDecode(raw);
      final fetchedAt = DateTime.tryParse(at)?.toUtc();
      if (decoded is! Map<String, dynamic> || fetchedAt == null) return null;
      return CachedLinesFeed(LinesThatLandResponse.fromJson(decoded), fetchedAt);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(LinesThatLandResponse response, DateTime fetchedAt) async {
    await _prefs.setString(PrefsKeys.linesThatLandCache, jsonEncode(response.toJson()));
    await _prefs.setString(PrefsKeys.linesThatLandFetchedAt, fetchedAt.toUtc().toIso8601String());
  }
}
