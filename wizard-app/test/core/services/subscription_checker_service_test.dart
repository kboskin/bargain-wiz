import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/core/services/subscription/subscription_checker_service.dart';
import 'package:appwizard/core/services/profile_cache.dart';
import 'package:appwizard/features/profile/data/models/profile_api_models.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_status.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';
import 'package:appwizard/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SilentLogger implements AppLogger {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeRepository implements SubscriptionRepository {
  Either<Failure, SubscriptionStatus?> status = const Right(null);
  @override
  Future<Either<Failure, SubscriptionStatus?>> getSubscriptionStatus() async => status;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late _FakeRepository repository;
  late ProfileCache profile;
  late SubscriptionCheckerService checker;

  const bought = SubscriptionStatus(tier: SubscriptionTier.premium, isActive: true, productId: 'p.weekly');

  /// The profile the server sent, carrying an operator's grant of `premium` until [until].
  ProfileDocument grant({DateTime? until}) => ProfileDocument(
        subscription: ProfileSubscription(
          operatorOverride: ProfileSubscriptionOverride(tier: 'premium', until: until?.toUtc().toIso8601String()),
        ),
      );
  final running = DateTime.now().add(const Duration(days: 1));
  final ended = DateTime.now().subtract(const Duration(days: 1));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = _FakeRepository();
    profile = ProfileCache(await SharedPreferences.getInstance());
    checker = SubscriptionCheckerService(repository, _SilentLogger(), profile);
  });

  test('a user with no purchase and no override is free', () async {
    expect(await checker.getCurrentTier(), SubscriptionTier.free);
  });

  test('an operator override lets a user in who bought nothing', () async {
    await profile.save(grant(until: running));
    expect(await checker.getCurrentTier(), SubscriptionTier.premium);
    expect(await checker.getCurrentStatus(), isNull, reason: 'the override is not a purchase');
  });

  test('an override with no end date stays until the profile drops it', () async {
    await profile.save(grant());
    expect(await checker.getCurrentTier(), SubscriptionTier.premium);

    await profile.save(null);
    expect(await checker.getCurrentTier(), SubscriptionTier.free);
  });

  test('an override that has run out lets nobody in, even offline', () async {
    await profile.save(grant(until: ended));
    expect(await checker.getCurrentTier(), SubscriptionTier.free);
  });

  test('a purchase is premium with or without an override', () async {
    repository.status = const Right(bought);
    expect(await checker.getCurrentTier(), SubscriptionTier.premium);

    await profile.save(grant(until: ended));
    expect(await checker.getCurrentTier(), SubscriptionTier.premium, reason: 'a lapsed grant never downgrades a purchase');
  });

  test('an override still works when the store status cannot be read', () async {
    repository.status = const Left(CacheFailure('boom'));
    expect(await checker.getCurrentTier(), SubscriptionTier.free);

    await profile.save(grant(until: running));
    expect(await checker.getCurrentTier(), SubscriptionTier.premium);
  });
}
