import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/services/analytics_service.dart';
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/theme/app_text_styles.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/core/widgets/styled_title_widget.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/paywall/data/models/paywall_config.dart';
import 'package:appwizard/features/paywall/data/models/paywall_layout.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_product.dart';
import 'package:appwizard/l10n/app_localizations.dart';
import 'package:appwizard/features/subscription/presentation/bloc/subscription_bloc.dart';
import 'package:appwizard/features/subscription/presentation/bloc/subscription_event.dart';
import 'package:appwizard/features/subscription/presentation/bloc/subscription_state.dart';

/// Widget for paywall-type onboarding screens
/// Fetches paywall config from Remote Config and renders the paywall UI
class PaywallScreenWidget extends StatefulWidget {
  final PaywallScreenModel model;
  /// Called when the user taps the close (X) button. In debug mode X is shown and triggers this to reach the post-paywall screen.
  final VoidCallback? onClose;

  const PaywallScreenWidget({
    super.key,
    required this.model,
    this.onClose,
  });

  @override
  State<PaywallScreenWidget> createState() => _PaywallScreenWidgetState();
}

class _PaywallScreenWidgetState extends State<PaywallScreenWidget> {
  PaywallConfig? _paywallConfig;
  String? _selectedOptionId;
  List<SubscriptionProduct> _products = [];
  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _closeButtonVisible = false;
  Timer? _closeButtonTimer;
  final AppLogger _logger = di.sl<AppLogger>();
  final AnalyticsService _analytics = di.sl<AnalyticsService>();
  final RemoteConfigService _remoteConfigService = di.sl<RemoteConfigService>();

  @override
  void initState() {
    super.initState();
    _loadPaywallConfig();
    _loadProducts();
  }

  @override
  void dispose() {
    _closeButtonTimer?.cancel();
    super.dispose();
  }

  void _scheduleCloseButtonVisibility() {
    if (_paywallConfig == null || widget.onClose == null) return;
    final config = _paywallConfig!;
    if (!config.showClose && !kDebugMode) return;

    final delaySeconds = config.closeButtonDelaySeconds;
    if (delaySeconds <= 0) {
      if (mounted) setState(() => _closeButtonVisible = true);
      return;
    }
    _closeButtonTimer?.cancel();
    _closeButtonTimer = Timer(Duration(milliseconds: (delaySeconds * 1000).round()), () {
      if (mounted) setState(() => _closeButtonVisible = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Log paywall impression when config is loaded
    if (_paywallConfig != null && !_isLoading) {
      _analytics.logPaywallImpression(
        paywallType: _paywallConfig!.type,
      );
    }
  }

  Future<void> _loadPaywallConfig() async {
    try {
      final config = _remoteConfigService.getPaywallConfig(
        configKey: widget.model.paywallConfigKey,
      );
      if (config != null) {
        setState(() {
          _paywallConfig = config;
          _selectedOptionId = config.metadata.defaultSelectedOptionId;
        });
        _scheduleCloseButtonVisibility();
      } else {
        _logger.w('Failed to load paywall config');
      }
    } catch (e, stackTrace) {
      _logger.e('Error loading paywall config', e, stackTrace);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProducts() async {
    final bloc = context.read<SubscriptionBloc>();
    bloc.add(const LoadProductsRequested());
  }

  SubscriptionProduct? _getProductForOption(PaywallOption option) {
    try {
      return _products.firstWhere(
        (p) => p.tier == option.tierEnum,
      );
    } catch (e) {
      _logger.w('Product not found for option tier ${option.tier}: $e');
      return null;
    }
  }

  Future<void> _handlePurchase() async {
    if (_paywallConfig == null || _selectedOptionId == null) return;

    final selectedOption = _paywallConfig!.options.firstWhere(
      (opt) => opt.id == _selectedOptionId,
    );

    final product = _getProductForOption(selectedOption);
    if (product == null) {
      _logger.w('Product not available for tier: ${selectedOption.tier}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.productNotAvailable),
        ),
      );
      return;
    }

    setState(() {
      _isPurchasing = true;
    });

    // Log analytics
    _analytics.logPaywallCtaTap(
      paywallType: _paywallConfig!.type,
      tier: selectedOption.tier,
    );

    final bloc = context.read<SubscriptionBloc>();
    bloc.add(PurchaseSubscriptionRequested(product.productId));
  }

  Future<void> _handleRestore() async {
    if (_paywallConfig == null) return;

    _analytics.logEvent(
      name: 'restore_tap',
      parameters: {
        'paywall_type': _paywallConfig!.type,
      },
    );

    final bloc = context.read<SubscriptionBloc>();
    bloc.add(const RestorePurchasesRequested());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _paywallConfig == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return BlocListener<SubscriptionBloc, SubscriptionState>(
      listener: (context, state) {
        if (state is PurchaseSuccess) {
          setState(() {
            _isPurchasing = false;
          });
          
          // Log analytics
          if (_paywallConfig != null) {
            final selectedOption = _paywallConfig!.options.firstWhere(
              (opt) => opt.id == _selectedOptionId,
              orElse: () => _paywallConfig!.options.first,
            );
            _analytics.logEvent(
              name: 'purchase_success',
              parameters: {
                'paywall_type': _paywallConfig!.type,
                'tier': selectedOption.tier,
              },
            );
          }
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.subscriptionActivated),
              backgroundColor: Colors.green,
            ),
          );
          
          // Note: Onboarding flow will continue to next screen via the next button
          // The paywall screen doesn't auto-advance after purchase
        } else if (state is PurchaseError) {
          setState(() {
            _isPurchasing = false;
          });
          
          // Log analytics
          if (_paywallConfig != null) {
            final selectedOption = _paywallConfig!.options.firstWhere(
              (opt) => opt.id == _selectedOptionId,
              orElse: () => _paywallConfig!.options.first,
            );
            _analytics.logEvent(
              name: 'purchase_fail',
              parameters: {
                'paywall_type': _paywallConfig!.type,
                'tier': selectedOption.tier,
                'error': state.message,
              },
            );
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        } else if (state is ProductsLoaded) {
          setState(() {
            _products = state.products;
            // Auto-select a purchasable option if current selection isn't available
            if (_paywallConfig != null && _selectedOptionId != null) {
              final currentOption = _paywallConfig!.options.firstWhere(
                (opt) => opt.id == _selectedOptionId,
                orElse: () => _paywallConfig!.options.first,
              );
              final currentProduct = _getProductForOption(currentOption);
              if (currentProduct == null && _products.isNotEmpty) {
                // Find first available option
                for (final option in _paywallConfig!.options) {
                  final product = _getProductForOption(option);
                  if (product != null) {
                    _selectedOptionId = option.id;
                    break;
                  }
                }
              }
            }
          });
        }
      },
      child: BlocBuilder<SubscriptionBloc, SubscriptionState>(
        builder: (context, state) {
          if (state is ProductsLoaded) {
            _products = state.products;
          }

          return _buildPaywallWithClose(context);
        },
      ),
    );
  }

  /// Wraps paywall content with an optional close (X) button when config.showClose or in debug mode.
  /// Button appears after close_button_delay_seconds (remotely configurable; default 5s).
  Widget _buildPaywallWithClose(BuildContext context) {
    final config = _paywallConfig!;
    final closeButtonEnabled = widget.onClose != null &&
        (config.showClose || kDebugMode);
    final showCloseButton = closeButtonEnabled && _closeButtonVisible;

    final content = _buildPaywallContent(context);
    if (!showCloseButton) return content;

    return Stack(
      children: [
        content,
        Positioned(
          top: 16,
          right: 16,
          child: IconButton(
            icon: const Icon(Icons.close, color: AppColors.backgroundDark),
            onPressed: widget.onClose,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.backgroundDark.withValues(alpha: 0.1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaywallContent(BuildContext context) {
    final config = _paywallConfig!;
    final selectedOption = config.options.firstWhere(
      (opt) => opt.id == _selectedOptionId,
      orElse: () => config.options.first,
    );

    // Use layout-based template
    switch (config.metadata.layout) {
      case PaywallLayout.cards:
        return _buildCardsLayout(context, config, selectedOption);
      case PaywallLayout.list:
        return _buildListLayout(context, config, selectedOption);
      case PaywallLayout.compact:
        return _buildCompactLayout(context, config, selectedOption);
    }
  }

  /// Cards layout - default vertical stacked cards
  Widget _buildCardsLayout(
    BuildContext context,
    PaywallConfig config,
    PaywallOption selectedOption,
  ) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            // Title
            StyledTitleWidget(
              title: config.title.get(context),
              highlightWordsData: config.titleHighlightWords?.description,
              highlightColor: config.metadata.highlightColor,
              baseColor: AppColors.backgroundDark,
              fontSize: 34,
              fontSizeHighlight: 38,
            ),
            const SizedBox(height: 16),
            // Description
            Text(
              config.description.get(context),
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.backgroundDark.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Visual (Lottie) - changes based on selected option
            _buildVisual(selectedOption.id, config.metadata),
            const SizedBox(height: 32),
            // Option cards
            ...config.options.map((option) => _buildOptionCard(
                  context,
                  option,
                  config,
                  isSelected: option.id == _selectedOptionId,
                )),
            const SizedBox(height: 24),
            // CTA Button
            _buildCtaButton(context, config, selectedOption),
            const SizedBox(height: 12),
            // Note text
            Text(
              config.noteText.get(context),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.backgroundDark.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Restore purchases button
            if (config.showRestore) _buildRestoreButton(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// List layout - horizontal list of options
  Widget _buildListLayout(
    BuildContext context,
    PaywallConfig config,
    PaywallOption selectedOption,
  ) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            // Title
            StyledTitleWidget(
              title: config.title.get(context),
              highlightWordsData: config.titleHighlightWords?.description,
              highlightColor: config.metadata.highlightColor,
              baseColor: AppColors.backgroundDark,
              fontSize: 34,
              fontSizeHighlight: 38,
            ),
            const SizedBox(height: 16),
            // Description
            Text(
              config.description.get(context),
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.backgroundDark.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Visual (Lottie) - changes based on selected option
            _buildVisual(selectedOption.id, config.metadata),
            const SizedBox(height: 24),
            // Option cards in horizontal scroll
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: config.options.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final option = config.options[index];
                  return SizedBox(
                    width: 200,
                    child: _buildOptionCard(
                      context,
                      option,
                      config,
                      isSelected: option.id == _selectedOptionId,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            // CTA Button
            _buildCtaButton(context, config, selectedOption),
            const SizedBox(height: 12),
            // Note text
            Text(
              config.noteText.get(context),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.backgroundDark.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Restore purchases button
            if (config.showRestore) _buildRestoreButton(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Compact layout - minimal spacing, smaller visual
  Widget _buildCompactLayout(
    BuildContext context,
    PaywallConfig config,
    PaywallOption selectedOption,
  ) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            // Title
            StyledTitleWidget(
              title: config.title.get(context),
              highlightWordsData: config.titleHighlightWords?.description,
              highlightColor: config.metadata.highlightColor,
              baseColor: AppColors.backgroundDark,
              fontSize: 28,
              fontSizeHighlight: 32,
            ),
            const SizedBox(height: 8),
            // Description
            Text(
              config.description.get(context),
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.backgroundDark.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Visual (Lottie) - smaller size
            _buildVisual(selectedOption.id, config.metadata),
            const SizedBox(height: 16),
            // Option cards - compact
            ...config.options.map((option) => _buildOptionCard(
                  context,
                  option,
                  config,
                  isSelected: option.id == _selectedOptionId,
                  compact: true,
                )),
            const SizedBox(height: 16),
            // CTA Button
            _buildCtaButton(context, config, selectedOption),
            const SizedBox(height: 8),
            // Note text
            Text(
              config.noteText.get(context),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.backgroundDark.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // Restore purchases button
            if (config.showRestore) _buildRestoreButton(context),
            // Terms & Privacy links
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCtaButton(
    BuildContext context,
    PaywallConfig config,
    PaywallOption selectedOption,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_isPurchasing || _getProductForOption(selectedOption) == null)
            ? null
            : _handlePurchase,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.backgroundDark,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: AppColors.backgroundDark.withValues(alpha: 0.5),
        ),
        child: _isPurchasing
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                config.nextButtonText.get(context),
                style: AppTextStyles.buttonText,
              ),
      ),
    );
  }

  Widget _buildRestoreButton(BuildContext context) {
    return TextButton(
      onPressed: _isPurchasing ? null : _handleRestore,
      child: Text(
        AppLocalizations.of(context)!.restorePurchases,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.backgroundDark.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildVisual(String optionId, PaywallMetadata metadata) {
    final visualPath = metadata.optionVisuals[optionId];
    if (visualPath == null || visualPath.isEmpty) {
      return const SizedBox.shrink();
    }

    return Opacity(
      opacity: metadata.visualOpacity ?? 0.95,
      child: VisualAssetWidget(
        visualPath: visualPath,
        width: metadata.visualWidth ?? 170.0,
        height: metadata.visualHeight ?? 170.0,
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context,
    PaywallOption option,
    PaywallConfig config, {
    required bool isSelected,
    bool compact = false,
  }) {
    final product = _getProductForOption(option);
    final hasProduct = product != null;

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 8.0 : 12.0),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedOptionId = option.id;
          });
          _analytics.logPaywallOptionSelected(
            paywallType: config.type,
            optionId: option.id,
            tier: option.tier,
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(compact ? 12.0 : 16.0),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? AppColors.backgroundDark
                  : AppColors.backgroundDark.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
            color: isSelected
                ? AppColors.backgroundDark.withValues(alpha: 0.1)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              // Selection indicator
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.backgroundDark
                        : AppColors.backgroundDark.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  color: isSelected
                      ? AppColors.backgroundDark
                      : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              // Option content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            option.title.get(context),
                            style: AppTextStyles.heading3.copyWith(
                              color: AppColors.backgroundDark,
                            ),
                          ),
                        ),
                        if (option.badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundDark,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              option.badge!.get(context),
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option.description.get(context),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.backgroundDark.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Price
              if (hasProduct && product.price != null)
                Text(
                  product.price!,
                  style: AppTextStyles.heading3.copyWith(
                    color: AppColors.backgroundDark,
                  ),
                )
              else if (!hasProduct)
                Text(
                  'N/A',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.backgroundDark.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

}
