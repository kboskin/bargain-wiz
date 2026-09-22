import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/routing/app_routes.dart';
import 'package:appwizard/core/services/feature_gate_service.dart';
import 'package:appwizard/features/paywall/domain/paywall_args.dart';

export 'package:appwizard/features/paywall/domain/paywall_args.dart';

/// Opens the paywall as a full-screen route and reports whether access was granted.
class PaywallLauncher {
  PaywallLauncher._();

  static Future<bool> open(
    BuildContext context, {
    PaywallEntry entry = PaywallEntry.other,
    String? preselectOptionId,
  }) async {
    final result = await context.push<bool>(
      AppRoutes.paywall,
      extra: PaywallArgs(entry: entry, preselectOptionId: preselectOptionId),
    );
    di.sl<FeatureGateService>().invalidate();
    return result == true;
  }
}

/// Gate + paywall in one call. Returns true when the feature may proceed
/// (already allowed, or the user just subscribed).
class FeatureAccess {
  FeatureAccess._();

  static Future<bool> ensure(BuildContext context, GatedFeature feature) async {
    final gate = di.sl<FeatureGateService>();
    final decision = await gate.check(feature);
    if (decision.allowed) return true;
    if (!context.mounted) return false;
    return PaywallLauncher.open(context, entry: entryFor(feature));
  }

  static PaywallEntry entryFor(GatedFeature feature) {
    switch (feature) {
      case GatedFeature.expressDealmaker:
        return PaywallEntry.expressFree;
      case GatedFeature.proDealCloser:
        return PaywallEntry.proFree;
      case GatedFeature.linesThatLand:
      case GatedFeature.history:
      case GatedFeature.profile:
        return PaywallEntry.other;
    }
  }
}
