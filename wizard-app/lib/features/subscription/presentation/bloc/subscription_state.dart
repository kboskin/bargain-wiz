import 'package:appwizard/features/shared/presentation/bloc/base_bloc.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_product.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_status.dart';

/// Subscription states
abstract class SubscriptionState extends BaseState {
  const SubscriptionState();
}

/// Initial state
class SubscriptionInitial extends SubscriptionState {
  const SubscriptionInitial();
}

/// Loading state
class SubscriptionLoading extends SubscriptionState {
  const SubscriptionLoading();
}

/// Products loaded successfully
class ProductsLoaded extends SubscriptionState {
  final List<SubscriptionProduct> products;
  final SubscriptionStatus? currentStatus;

  const ProductsLoaded({
    required this.products,
    this.currentStatus,
  });

  ProductsLoaded copyWith({
    List<SubscriptionProduct>? products,
    SubscriptionStatus? currentStatus,
  }) {
    return ProductsLoaded(
      products: products ?? this.products,
      currentStatus: currentStatus ?? this.currentStatus,
    );
  }

  @override
  List<Object?> get props => [products, currentStatus];
}

/// Purchase in progress
class PurchaseInProgress extends SubscriptionState {
  const PurchaseInProgress();
}

/// Purchase successful
class PurchaseSuccess extends SubscriptionState {
  final SubscriptionStatus status;

  const PurchaseSuccess(this.status);

  @override
  List<Object> get props => [status];
}

/// Purchase error
class PurchaseError extends SubscriptionState {
  final String message;

  const PurchaseError(this.message);

  @override
  List<Object> get props => [message];
}

/// Subscription status checked
class StatusChecked extends SubscriptionState {
  final SubscriptionStatus? status;

  const StatusChecked(this.status);

  @override
  List<Object?> get props => [status];
}
