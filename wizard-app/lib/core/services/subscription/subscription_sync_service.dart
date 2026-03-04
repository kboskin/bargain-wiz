import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:appwizard/core/services/auth_service.dart';
import 'package:appwizard/core/services/subscription/payment_provider.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/subscription/data/models/subscription_model.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_status.dart';
import 'package:appwizard/core/config/app_config.dart';

/// Service for syncing subscription status with backend
/// Handles receipt verification and fetching subscription status
class SubscriptionSyncService {
  final AuthService _authService;
  final Dio _dio;
  final AppLogger _logger;

  SubscriptionSyncService(
    this._authService,
    this._dio,
    this._logger,
  );

  /// Verify receipt with backend and sync subscription status
  /// Backend verifies receipt with App Store/Play Store server-side
  Future<SubscriptionStatus?> verifyAndSyncReceipt(
    PurchaseDetails purchase,
  ) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        _logger.w('Cannot verify receipt: user not authenticated');
        return null;
      }

      _logger.i('Verifying receipt with backend for product: ${purchase.productId}');

      // Get Firebase ID token for authentication
      final idToken = await user.getIdToken();

      // Prepare request payload
      final payload = {
        'receipt_data': purchase.receiptData,
        'transaction_id': purchase.transactionId,
        if (purchase.originalTransactionId != null)
          'original_transaction_id': purchase.originalTransactionId,
        'platform': purchase.platform,
        'user_id': user.uid,
        'product_id': purchase.productId,
        'sandbox': AppConfig.isDev,
      };

      // Send to backend for verification
      final response = await _dio.post(
        '${AppConfig.baseUrl}/api/v1/subscriptions/verify',
        data: payload,
        options: Options(
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final model = SubscriptionModel.fromJson(data);
        _logger.i('Receipt verified successfully, subscription synced');
        return model.toEntity();
      } else {
        _logger.w('Receipt verification failed: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Error verifying receipt with backend', e, stackTrace);
      return null;
    }
  }

  /// Fetch subscription status from backend
  /// Backend returns already-verified subscription status
  Future<SubscriptionStatus?> fetchFromBackend() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        _logger.w('Cannot fetch subscription: user not authenticated');
        return null;
      }

      _logger.i('Fetching subscription status from backend');

      // Get Firebase ID token for authentication
      final idToken = await user.getIdToken();

      // Fetch from backend
      final response = await _dio.get(
        '${AppConfig.baseUrl}/api/v1/subscriptions/users/${user.uid}',
        options: Options(
          headers: {
            'Authorization': 'Bearer $idToken',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final model = SubscriptionModel.fromJson(data);
        _logger.i('Subscription status fetched from backend');
        return model.toEntity();
      } else if (response.statusCode == 404) {
        // No subscription found - return null (free tier)
        _logger.i('No subscription found for user');
        return null;
      } else {
        _logger.w('Failed to fetch subscription: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching subscription from backend', e, stackTrace);
      return null;
    }
  }
}
