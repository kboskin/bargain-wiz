import 'package:appwizard/core/error/failures.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/shared/presentation/bloc/base_bloc.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_product.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_status.dart';
import 'package:appwizard/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:appwizard/features/subscription/presentation/bloc/subscription_event.dart';
import 'package:appwizard/features/subscription/presentation/bloc/subscription_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Subscription BLoC for managing subscription state
class SubscriptionBloc extends BaseBloc<SubscriptionEvent, SubscriptionState> {
  final SubscriptionRepository _repository;
  final AppLogger _logger;

  SubscriptionBloc({
    required SubscriptionRepository repository,
    required AppLogger logger,
  })  : _repository = repository,
        _logger = logger,
        super(const SubscriptionInitial()) {
    on<LoadProductsRequested>(_onLoadProductsRequested);
    on<PurchaseSubscriptionRequested>(_onPurchaseSubscriptionRequested);
    on<RestorePurchasesRequested>(_onRestorePurchasesRequested);
    on<CheckSubscriptionStatusRequested>(_onCheckSubscriptionStatusRequested);
    on<RefreshSubscriptionStatusRequested>(_onRefreshSubscriptionStatusRequested);

    // Check subscription status on initialization if user is authenticated
    add(const CheckSubscriptionStatusRequested());
  }

  Future<void> _onLoadProductsRequested(
    LoadProductsRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(const SubscriptionLoading());
    try {
      final result = await _repository.getAvailableProducts();
      final products = result.fold<List<SubscriptionProduct>?>(
        (failure) {
          _logger.e('Failed to load products', failure);
          return null;
        },
        (products) => products,
      );
      if (products == null) {
        emit(const ProductsLoaded(products: []));
        return;
      }
      // Also get current status
      final status = await _currentStatus();
      emit(ProductsLoaded(products: products, currentStatus: status));
    } catch (e, stackTrace) {
      _logger.e('Error loading products', e, stackTrace);
      emit(const ProductsLoaded(products: []));
    }
  }

  Future<void> _onPurchaseSubscriptionRequested(
    PurchaseSubscriptionRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(const PurchaseInProgress());
    try {
      final result = await _repository.purchaseSubscription(event.productId);
      final failure = result.fold<Failure?>((failure) => failure, (_) => null);
      if (failure != null) {
        _logger.e('Purchase failed', failure);
        emit(PurchaseError(failure.message));
        return;
      }
      // Get updated status after purchase
      final status = await _currentStatus();
      if (status != null) {
        emit(PurchaseSuccess(status));
      } else {
        emit(const PurchaseError('Purchase completed but status not available'));
      }
    } catch (e, stackTrace) {
      _logger.e('Error purchasing subscription', e, stackTrace);
      emit(PurchaseError(e.toString()));
    }
  }

  Future<void> _onRestorePurchasesRequested(
    RestorePurchasesRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(const SubscriptionLoading());
    try {
      final result = await _repository.restorePurchases();
      final failure = result.fold<Failure?>((failure) => failure, (_) => null);
      if (failure != null) {
        _logger.e('Failed to restore purchases', failure);
        emit(PurchaseError(failure.message));
        return;
      }
      // Get updated status after restore
      emit(StatusChecked(await _currentStatus()));
    } catch (e, stackTrace) {
      _logger.e('Error restoring purchases', e, stackTrace);
      emit(PurchaseError(e.toString()));
    }
  }

  Future<void> _onCheckSubscriptionStatusRequested(
    CheckSubscriptionStatusRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      final result = await _repository.getSubscriptionStatus();
      result.fold(
        (failure) {
          _logger.e('Failed to check subscription status', failure);
          emit(const StatusChecked(null));
        },
        (status) {
          emit(StatusChecked(status));
        },
      );
    } catch (e, stackTrace) {
      _logger.e('Error checking subscription status', e, stackTrace);
      emit(const StatusChecked(null));
    }
  }

  Future<void> _onRefreshSubscriptionStatusRequested(
    RefreshSubscriptionStatusRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(const SubscriptionLoading());
    try {
      final result = await _repository.getSubscriptionStatus();
      result.fold(
        (failure) {
          _logger.e('Failed to refresh subscription status', failure);
          emit(const StatusChecked(null));
        },
        (status) {
          emit(StatusChecked(status));
        },
      );
    } catch (e, stackTrace) {
      _logger.e('Error refreshing subscription status', e, stackTrace);
      emit(const StatusChecked(null));
    }
  }

  /// Current status, or null when it cannot be read.
  Future<SubscriptionStatus?> _currentStatus() async {
    final result = await _repository.getSubscriptionStatus();
    return result.fold((failure) => null, (status) => status);
  }
}
