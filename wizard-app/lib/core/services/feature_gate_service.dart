import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:appwizard/core/config/app_config.dart';
import 'package:appwizard/core/config/feature_gate_policy.dart';
import 'package:appwizard/core/services/subscription/subscription_checker_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';

export 'package:appwizard/core/config/feature_gate_policy.dart';

/// Decides whether a feature is available for the current tier, per [FeatureGatePolicy].
///
/// Free: Lines that land only; Express and Pro open the paywall.
/// Premium: everything.
///
/// In debug / dev builds a tier override can be set (Profile → developer row) so QA can
/// walk every gate without a store purchase.
class FeatureGateService extends ChangeNotifier {
  FeatureGateService(this._checker, this._prefs, this._logger);

  static const String debugTierKey = 'debug_tier_override';

  final SubscriptionCheckerService _checker;
  final SharedPreferences _prefs;
  final AppLogger _logger;

  SubscriptionTier? _lastTier;

  /// Last resolved tier (synchronous, may be null before the first [currentTier]).
  SubscriptionTier? get lastTier => _lastTier;

  bool get canOverride => kDebugMode || AppConfig.enableDebugFeatures;

  SubscriptionTier? get debugOverride {
    if (!canOverride) return null;
    final v = _prefs.getString(debugTierKey);
    if (v == null) return null;
    return SubscriptionTier.values.where((t) => t.name == v).firstOrNull;
  }

  Future<void> setDebugOverride(SubscriptionTier? tier) async {
    if (!canOverride) return;
    if (tier == null) {
      await _prefs.remove(debugTierKey);
    } else {
      await _prefs.setString(debugTierKey, tier.name);
    }
    _lastTier = null;
    notifyListeners();
  }

  /// Resolves the effective tier (debug override → subscription status → free).
  Future<SubscriptionTier> currentTier() async {
    final override = debugOverride;
    if (override != null) {
      _lastTier = override;
      return override;
    }
    try {
      final tier = await _checker.getCurrentTier();
      _lastTier = tier;
      return tier;
    } catch (e, st) {
      _logger.e('FeatureGateService.currentTier failed', e, st);
      _lastTier = SubscriptionTier.free;
      return SubscriptionTier.free;
    }
  }

  Future<GateDecision> check(GatedFeature feature) async {
    final tier = await currentTier();
    return FeatureGatePolicy.decide(tier, feature);
  }

  /// Call after a purchase / restore so cached tier is re-read.
  void invalidate() {
    _lastTier = null;
    notifyListeners();
  }
}
