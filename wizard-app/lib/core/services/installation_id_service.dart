import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:appwizard/core/config/prefs_keys.dart';

/// A random UUID v4 minted on first launch and kept in preferences. It identifies this
/// install to the `profile` Cloud Function while the user is signed out; after sign-in the
/// server folds the install's profile into the account's (see PROFILE_SYNC.md).
class InstallationIdService {
  InstallationIdService(this._prefs, {Random? random}) : _random = random ?? Random.secure();

  final SharedPreferences _prefs;
  final Random _random;

  String get id {
    final existing = _prefs.getString(PrefsKeys.installationId);
    if (existing != null && existing.isNotEmpty) return existing;
    final fresh = generate(_random);
    _prefs.setString(PrefsKeys.installationId, fresh);
    return fresh;
  }

  /// RFC 4122 version 4 UUID, lower-case, hyphenated.
  static String generate(Random random) {
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10xx
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
