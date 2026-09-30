import 'dart:async';

import 'package:appwizard/core/config/prefs_keys.dart';
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/services/subscription/payment_provider.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/subscription/data/datasources/subscription_in_memory_datasource.dart';
import 'package:appwizard/features/subscription/data/models/subscription_config.dart';
import 'package:appwizard/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_status.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SilentLogger implements AppLogger {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NoConfig implements RemoteConfigService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A `subscription_config` whose plan ids are not the bundled ones.
class _Config implements RemoteConfigService {
  @override
  SubscriptionConfig? getSubscriptionConfig() => SubscriptionConfig(products: [
        SubscriptionProductConfig(
          id: 'yearly',
          tier: 'premium',
          productId: ProductIdConfig(ios: 'ios.yearly', android: 'android.yearly'),
          title: 'Yearly',
          description: 'Billed yearly',
          features: const [],
          displayOrder: 1,
        ),
        SubscriptionProductConfig(
          tier: 'premium',
          productId: ProductIdConfig(ios: 'ios.keyless', android: 'android.keyless'),
          title: 'Keyless',
          description: 'A product with no plan id',
          features: const [],
          displayOrder: 2,
        ),
      ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

PurchaseDetails _purchase(String productId) => PurchaseDetails(
      productId: productId,
      transactionId: 'tx-$productId',
      transactionDate: DateTime(2026, 9, 16),
      receiptData: 'token',
      platform: 'android',
    );

class _FakePayment extends PaymentProvider {
  _FakePayment(super.logger);

  final controller = StreamController<PurchaseUpdate>.broadcast();
  List<PurchaseDetails> restoreResult = const [];
  int initializeCalls = 0;
  bool confirmImmediately = false;

  @override
  Future<bool> initialize() async {
    initializeCalls++;
    return true;
  }

  @override
  Future<List<StoreProduct>> loadProducts(List<String> productIds) async =>
      [for (final id in productIds) StoreProduct(productId: id, price: '\$1')];

  @override
  Future<PurchaseResult> purchaseProduct(String productId) async {
    // Some stores confirm before the initiating call returns.
    if (confirmImmediately) controller.add(PurchaseUpdate.success(_purchase(productId)));
    return PurchaseResult.success(_purchase(productId));
  }

  @override
  Future<List<PurchaseDetails>> restorePurchases() async => restoreResult;

  @override
  Stream<PurchaseUpdate> get purchaseUpdates => controller.stream;
}

void main() {
  late _FakePayment payment;
  late SharedPreferences prefs;

  Future<SubscriptionRepositoryImpl> repo() async => SubscriptionRepositoryImpl(
        payment,
        SubscriptionInMemoryDataSourceImpl(_SilentLogger()),
        _NoConfig(),
        prefs,
        _SilentLogger(),
        restoreWindow: Duration.zero,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    payment = _FakePayment(_SilentLogger());
  });

  tearDown(() => payment.controller.close());

  test('a completed purchase becomes the entitlement and is persisted', () async {
    final r = await repo();
    final pending = r.purchaseSubscription('com.bargain.wiz.premium.monthly');
    await Future<void>.delayed(Duration.zero);
    payment.controller.add(PurchaseUpdate.success(_purchase('com.bargain.wiz.premium.monthly')));

    expect((await pending).isRight(), isTrue);
    final status = (await r.getSubscriptionStatus()).getOrElse(() => null)!;
    expect(status.tier, SubscriptionTier.premium);
    expect(status.isActive, isTrue);
    expect(status.plan, 'monthly');
    expect(prefs.getString(PrefsKeys.subscriptionStatus), contains('premium'));
    await r.dispose();
  });

  test('initialises the store provider so the purchase stream flows', () async {
    final r = await repo();
    await Future<void>.delayed(Duration.zero);
    expect(payment.initializeCalls, 1);
    await r.dispose();
  });

  test('a confirmation that arrives before the initiating call returns is not lost', () async {
    payment.confirmImmediately = true;
    final r = await repo();
    final result = await r.purchaseSubscription('com.bargain.wiz.premium.weekly');
    expect(result.isRight(), isTrue);
    expect((await r.getSubscriptionStatus()).getOrElse(() => null)?.tier, SubscriptionTier.premium);
    await r.dispose();
  });

  test('the persisted entitlement is known at cold start', () async {
    final first = await repo();
    payment.controller.add(PurchaseUpdate.success(_purchase('com.bargain.wiz.premium.weekly')));
    await Future<void>.delayed(Duration.zero);
    await first.dispose();

    final second = await repo();
    final status = (await second.getSubscriptionStatus()).getOrElse(() => null);
    expect(status?.tier, SubscriptionTier.premium);
    expect(status?.productId, 'com.bargain.wiz.premium.weekly');
    expect(status?.plan, 'weekly');
    await second.dispose();
  });

  test('restore clears a lapsed entitlement when the store reports nothing', () async {
    final r = await repo();
    payment.controller.add(PurchaseUpdate.success(_purchase('com.bargain.wiz.premium.weekly')));
    await Future<void>.delayed(Duration.zero);

    payment.restoreResult = const [];
    expect((await r.restorePurchases()).isRight(), isTrue);

    expect((await r.getSubscriptionStatus()).getOrElse(() => null), isNull);
    expect(prefs.getString(PrefsKeys.subscriptionStatus), isNull);
    await r.dispose();
  });

  test('reports every entitlement change, with the new one already readable', () async {
    SubscriptionTier? seen;
    SubscriptionStatus? told;
    var changes = 0;
    late SubscriptionRepositoryImpl r;
    r = SubscriptionRepositoryImpl(
      payment,
      SubscriptionInMemoryDataSourceImpl(_SilentLogger()),
      _NoConfig(),
      prefs,
      _SilentLogger(),
      restoreWindow: Duration.zero,
      onEntitlementChanged: (status) async {
        changes++;
        told = status;
        seen = (await r.getSubscriptionStatus()).getOrElse(() => null)?.tier;
      },
    );
    payment.controller.add(PurchaseUpdate.success(_purchase('com.bargain.wiz.premium.weekly')));
    await Future<void>.delayed(Duration.zero);
    expect((changes, seen), (1, SubscriptionTier.premium));
    expect(told?.plan, 'weekly'); // the callback is handed the new entitlement

    await r.restorePurchases(); // the store reports nothing: the entitlement is dropped
    await Future<void>.delayed(Duration.zero);
    expect((changes, seen, told), (2, null, null));
    await r.dispose();
  });

  test('restore keeps a paid purchase over an unknown one', () async {
    final r = await repo();
    payment.restoreResult = [_purchase('something.else'), _purchase('com.bargain.wiz.premium.monthly')];
    await r.restorePurchases();
    expect((await r.getSubscriptionStatus()).getOrElse(() => null)?.tier, SubscriptionTier.premium);
    await r.dispose();
  });

  test('tierForProduct falls back to the product id naming without config', () async {
    final r = await repo();
    expect(r.tierForProduct('com.bargain.wiz.premium.monthly'), SubscriptionTier.premium);
    expect(r.tierForProduct('com.bargain.wiz.premium.weekly'), SubscriptionTier.premium);
    expect(r.tierForProduct('something.else'), SubscriptionTier.free);
    await r.dispose();
  });

  test('planForProduct names the plan: the config id, else the bundled keys, else nothing', () async {
    final bundled = await repo();
    expect(bundled.planForProduct('com.bargain.wiz.premium.monthly'), 'monthly');
    expect(bundled.planForProduct('com.bargain.wiz.premium.weekly'), 'weekly');
    expect(bundled.planForProduct('something.else'), isNull);
    await bundled.dispose();

    final configured = SubscriptionRepositoryImpl(
      payment,
      SubscriptionInMemoryDataSourceImpl(_SilentLogger()),
      _Config(),
      prefs,
      _SilentLogger(),
      restoreWindow: Duration.zero,
    );
    expect(configured.planForProduct('android.yearly'), 'yearly'); // the config's id, on either platform
    expect(configured.planForProduct('ios.yearly'), 'yearly');
    expect(configured.planForProduct('ios.keyless'), isNull); // in the config, but with no plan id
    expect(configured.planForProduct('com.bargain.wiz.premium.weekly'), 'weekly'); // not in it: the bundled key
    await configured.dispose();
  });

  test('the bundled fallback products carry the paywall option keys', () async {
    final r = await repo();
    final products = (await r.getAvailableProducts()).getOrElse(() => const []);
    expect(products.map((p) => p.key), ['monthly', 'weekly']);
    expect(products.map((p) => p.productId), SubscriptionRepositoryImpl.fallbackProductIds.values);
    await r.dispose();
  });
}
