import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:appwizard/features/shared/presentation/bloc/base_bloc.dart';
import 'package:appwizard/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/subscription/presentation/bloc/subscription_event.dart';
import 'package:appwizard/features/subscription/presentation/bloc/subscription_state.dart';

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
      result.fold(
        (failure) {
          _logger.e('Failed to load products', failure);
          emit(ProductsLoaded(products: [], currentStatus: null));
        },
        (products) async {
          // Also get current status
          final statusResult = await _repository.getSubscriptionStatus();
          final status = statusResult.fold(
            (failure) => null,
            (status) => status,
          );
          emit(ProductsLoaded(products: products, currentStatus: status));
        },
      );
    } catch (e, stackTrace) {
      _logger.e('Error loading products', e, stackTrace);
      emit(ProductsLoaded(products: [], currentStatus: null));
    }
  }

  Future<void> _onPurchaseSubscriptionRequested(
    PurchaseSubscriptionRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(const PurchaseInProgress());
    try {
      final result = await _repository.purchaseSubscription(event.productId);
      result.fold(
        (failure) {
          _logger.e('Purchase failed', failure);
          emit(PurchaseError(failure.message));
        },
        (_) async {
          // Get updated status after purchase
          final statusResult = await _repository.getSubscriptionStatus();
          final status = statusResult.fold(
            (failure) => null,
            (status) => status,
          );
          if (status != null) {
            emit(PurchaseSuccess(status));
          } else {
            emit(const PurchaseError('Purchase completed but status not available'));
          }
        },
      );
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
      result.fold(
        (failure) {
          _logger.e('Failed to restore purchases', failure);
          emit(PurchaseError(failure.message));
        },
        (_) async {
          // Get updated status after restore
          final statusResult = await _repository.getSubscriptionStatus();
          final status = statusResult.fold(
            (failure) => null,
            (status) => status,
          );
          emit(StatusChecked(status));
        },
      );
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
}
