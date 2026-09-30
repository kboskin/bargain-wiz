import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:appwizard/core/config/prefs_keys.dart';
import 'package:appwizard/features/profile/data/models/profile_api_models.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_override.dart';

/// The last profile document the server sent, kept on the device (PROFILE_SYNC.md). The
/// profile is pulled at every launch, at sign-in and when onboarding finishes; when a pull
/// fails, or before it lands, the person is served from what the last one brought.
///
/// It exists for what only the server can say — today the operator's `subscription.override`
/// ([subscriptionOverride]). The answers in it are not read: `onboarding_data` stays their
/// record, and this copy may be older. [ProfileSyncService] fills it and drops it when the
/// signed-in account changes; [SubscriptionCheckerService] reads the override from it.
class ProfileCache {
  ProfileCache(this._prefs);

  final SharedPreferences _prefs;

  ProfileDocument? _document;
  bool _read = false;

  /// The cached document; null before the first pull, after the server had none, and once the
  /// account changed.
  ProfileDocument? get document {
    if (!_read) {
      _document = _load();
      _read = true;
    }
    return _document;
  }

  /// The account the document belongs to (`identity.uid`, from the ID token server-side).
  String? get uid => document?.identity?.uid;

  /// The grant the cached document carries — whether or not it has run out, which is
  /// [SubscriptionOverride.grantsAt]'s business; null when it carries none that is usable.
  SubscriptionOverride? get subscriptionOverride {
    final wire = document?.subscription?.operatorOverride;
    return wire == null ? null : SubscriptionOverride.fromWire(tier: wire.tier, until: wire.until);
  }

  /// Replaces the cached document with [doc]; null drops it.
  Future<void> save(ProfileDocument? doc) async {
    _document = doc;
    _read = true;
    if (doc == null) {
      await _prefs.remove(PrefsKeys.profileDocument);
    } else {
      await _prefs.setString(PrefsKeys.profileDocument, jsonEncode(doc.toJson()));
    }
  }

  ProfileDocument? _load() {
    final raw = _prefs.getString(PrefsKeys.profileDocument);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      return json is Map<String, dynamic> ? ProfileDocument.fromJson(json) : null;
    } on Object {
      return null;
    }
  }
}
