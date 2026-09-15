import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';

/// Gated features (see remote key `free_tier_rules`).
enum GatedFeature { linesThatLand, expressDealmaker, proDealCloser, history, profile }

/// Result of a gate check.
class GateDecision {
  const GateDecision.allowed()
      : allowed = true,
        hintKey = null;

  const GateDecision.paywall({this.hintKey}) : allowed = false;

  final bool allowed;
  /// Context hint key for the paywall ("free", "basic_express"), when blocked.
  final String? hintKey;
}

/// Parsed `free_tier_rules`:
/// ```json
/// {"free": {"lines_that_land": true, "express_dealmaker": "paywall", ...},
///  "basic": {"express_dealmaker": "paywall(hint=basic_express)", ...},
///  "premium": {"all": true}}
/// ```
class FeatureGateConfig {
  const FeatureGateConfig(this._rules);

  final Map<String, Map<String, dynamic>> _rules;

  static const FeatureGateConfig defaults = FeatureGateConfig({
    'free': {
      'lines_that_land': true,
      'express_dealmaker': 'paywall',
      'pro_deal_closer': 'paywall',
      'history': true,
      'profile': true,
    },
    'basic': {
      'lines_that_land': true,
      'express_dealmaker': 'paywall(hint=basic_express)',
      'pro_deal_closer': true,
      'history': true,
      'profile': true,
    },
    'premium': {'all': true},
  });

  static FeatureGateConfig fromJson(Map<String, dynamic> json) {
    final out = <String, Map<String, dynamic>>{};
    json.forEach((tier, rules) {
      if (rules is Map) out[tier] = Map<String, dynamic>.from(rules);
    });
    return FeatureGateConfig(out);
  }

  static String _key(GatedFeature f) {
    switch (f) {
      case GatedFeature.linesThatLand:
        return 'lines_that_land';
      case GatedFeature.expressDealmaker:
        return 'express_dealmaker';
      case GatedFeature.proDealCloser:
        return 'pro_deal_closer';
      case GatedFeature.history:
        return 'history';
      case GatedFeature.profile:
        return 'profile';
    }
  }

  GateDecision decide(SubscriptionTier tier, GatedFeature feature) {
    final rules = _rules[tier.name] ?? defaults._rules[tier.name] ?? const {};
    if (rules['all'] == true) return const GateDecision.allowed();
    final v = rules[_key(feature)];
    if (v == null) {
      // Unknown feature: allow for paid tiers, block for free.
      return tier == SubscriptionTier.free
          ? GateDecision.paywall(hintKey: 'free')
          : const GateDecision.allowed();
    }
    if (v == true) return const GateDecision.allowed();
    if (v is String && v.startsWith('paywall')) {
      final m = RegExp(r'hint=([a-zA-Z0-9_]+)').firstMatch(v);
      return GateDecision.paywall(hintKey: m?.group(1) ?? (tier == SubscriptionTier.free ? 'free' : null));
    }
    return const GateDecision.allowed();
  }
}
