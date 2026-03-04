import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/subscription/data/models/subscription_model.dart';

/// In-memory data source interface for subscription status
abstract class SubscriptionInMemoryDataSource {
  /// Save subscription status to memory
  void saveSubscriptionStatus(SubscriptionModel status);

  /// Get subscription status from memory
  SubscriptionModel? getSubscriptionStatus();

  /// Clear subscription status from memory
  void clearSubscriptionStatus();
}

/// Implementation of in-memory data source
/// RAM-based cache (not persistent, cleared on app close)
class SubscriptionInMemoryDataSourceImpl
    implements SubscriptionInMemoryDataSource {
  final AppLogger _logger;
  SubscriptionModel? _cachedStatus;

  SubscriptionInMemoryDataSourceImpl(this._logger);

  @override
  void saveSubscriptionStatus(SubscriptionModel status) {
    _cachedStatus = status;
    _logger.i('Subscription status cached in memory');
  }

  @override
  SubscriptionModel? getSubscriptionStatus() {
    return _cachedStatus;
  }

  @override
  void clearSubscriptionStatus() {
    _cachedStatus = null;
    _logger.i('Subscription status cache cleared');
  }
}
