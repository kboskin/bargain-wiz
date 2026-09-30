import 'package:equatable/equatable.dart';

import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';

/// A grant an operator wrote on the person's profile (`subscription.override`, see
/// PROFILE_SYNC.md) to let them in without a purchase: [tier] until [until], or with no end
/// date when that is null. The device never writes it; it only honours it.
class SubscriptionOverride extends Equatable {
  const SubscriptionOverride({required this.tier, this.until});

  /// The override as the profile carries it, or null when it grants nothing usable: no paid
  /// tier, or an end date that cannot be read — a grant that cannot be bounded is not one.
  static SubscriptionOverride? fromWire({String? tier, String? until}) {
    final granted = SubscriptionTier.fromName(tier?.trim().toLowerCase());
    if (granted == SubscriptionTier.free) return null;
    final end = until?.trim();
    if (end == null || end.isEmpty) return SubscriptionOverride(tier: granted);
    final parsed = DateTime.tryParse(end);
    return parsed == null ? null : SubscriptionOverride(tier: granted, until: parsed.toUtc());
  }

  final SubscriptionTier tier;
  final DateTime? until;

  /// Whether it lets the person in at [now].
  bool grantsAt(DateTime now) => until == null || now.isBefore(until!);

  @override
  List<Object?> get props => [tier, until];
}
