import 'package:appwizard/features/shared/presentation/bloc/base_bloc.dart';

/// Subscription events
abstract class SubscriptionEvent extends BaseEvent {
  const SubscriptionEvent();
}

/// Load available subscription products
class LoadProductsRequested extends SubscriptionEvent {
  const LoadProductsRequested();
}

/// Purchase a subscription
class PurchaseSubscriptionRequested extends SubscriptionEvent {
  final String productId;

  const PurchaseSubscriptionRequested(this.productId);

  @override
  List<Object> get props => [productId];
}

/// Restore previous purchases
class RestorePurchasesRequested extends SubscriptionEvent {
  const RestorePurchasesRequested();
}

/// Check current subscription status
class CheckSubscriptionStatusRequested extends SubscriptionEvent {
  const CheckSubscriptionStatusRequested();
}

/// Refresh subscription status from backend
class RefreshSubscriptionStatusRequested extends SubscriptionEvent {
  const RefreshSubscriptionStatusRequested();
}
