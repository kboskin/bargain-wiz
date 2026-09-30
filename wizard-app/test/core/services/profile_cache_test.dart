import 'package:appwizard/core/config/prefs_keys.dart';
import 'package:appwizard/core/services/profile_cache.dart';
import 'package:appwizard/features/profile/data/models/profile_api_models.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_override.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late ProfileCache cache;

  const doc = ProfileDocument(
    identity: ProfileIdentity(uid: 'u1'),
    preferences: {'vibe': 'tactical'},
    subscription: ProfileSubscription(
      plan: 'weekly',
      operatorOverride: ProfileSubscriptionOverride(tier: 'premium', until: '2026-12-31T00:00:00Z'),
    ),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cache = ProfileCache(prefs);
  });

  test('holds nothing before the first pull', () {
    expect(cache.document, isNull);
    expect(cache.uid, isNull);
    expect(cache.subscriptionOverride, isNull);
  });

  test('keeps the pulled profile across restarts, and reads the grant out of it', () async {
    await cache.save(doc);

    final next = ProfileCache(prefs); // a new process over the same storage
    expect(next.uid, 'u1');
    expect(next.document!.subscription!.plan, 'weekly');
    expect(next.subscriptionOverride, SubscriptionOverride(tier: SubscriptionTier.premium, until: DateTime.utc(2026, 12, 31)));
  });

  test('a later pull replaces it, and a null (no profile on the server) drops it', () async {
    await cache.save(doc);
    await cache.save(const ProfileDocument(identity: ProfileIdentity(uid: 'u1')));
    expect(cache.subscriptionOverride, isNull);
    expect(ProfileCache(prefs).subscriptionOverride, isNull);

    await cache.save(null);
    expect(cache.document, isNull);
    expect(prefs.getString(PrefsKeys.profileDocument), isNull);
  });

  test('an unreadable cache is no cache', () async {
    await prefs.setString(PrefsKeys.profileDocument, '{not json');
    expect(ProfileCache(prefs).document, isNull);
    await prefs.setString(PrefsKeys.profileDocument, '["u1"]');
    expect(ProfileCache(prefs).document, isNull);
  });
}
