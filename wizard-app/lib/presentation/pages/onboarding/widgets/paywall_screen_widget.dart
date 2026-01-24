import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/remote_config_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/multilocale_text_helper.dart';
import '../../../../core/widgets/visual_asset_widget.dart';
import '../../../../data/models/remote_config/onboarding_model.dart';
import '../../../../data/models/remote_config/paywall_config.dart';
import '../../../../data/models/remote_config/paywall_layout.dart';
import '../../../../domain/entities/subscription_product.dart';
import '../../../../domain/entities/subscription_tier.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../bloc/subscription/subscription_bloc.dart';
import '../../../bloc/subscription/subscription_event.dart';
import '../../../bloc/subscription/subscription_state.dart';

/// Widget for paywall-type onboarding screens
/// Fetches paywall config from Remote Config and renders the paywall UI
class PaywallScreenWidget extends StatefulWidget {
  final PaywallScreenModel model;

  const PaywallScreenWidget({
    super.key,
    required this.model,
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
  final AppLogger _logger = di.sl<AppLogger>();
  final AnalyticsService _analytics = di.sl<AnalyticsService>();
  final RemoteConfigService _remoteConfigService = di.sl<RemoteConfigService>();
  final MultilocaleTextHelper _multilocaleTextHelper = di.sl<MultilocaleTextHelper>();

  @override
  void initState() {
    super.initState();
    _loadPaywallConfig();
    _loadProducts();
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

  String? _getProductIdForTier(SubscriptionTier tier) {
    final product = _products.firstWhere(
      (p) => p.tier == tier,
      orElse: () => _products.first,
    );
    return product.productId;
  }

  SubscriptionProduct? _getProductForOption(PaywallOption option) {
    try {
      return _products.firstWhere(
        (p) => p.tier == option.tierEnum,
      );
    } catch (e) {
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

          return _buildPaywallContent(context);
        },
      ),
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
            Text(
              _multilocaleTextHelper.getText(context, config.title),
              style: AppTextStyles.heading1.copyWith(
                color: AppColors.backgroundDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Description
            Text(
              _multilocaleTextHelper.getText(context, config.description),
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
              _multilocaleTextHelper.getText(context, config.noteText),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.backgroundDark.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Restore purchases button
            if (config.showRestore) _buildRestoreButton(context),
            // Terms & Privacy links
            _buildTermsAndPrivacyLinks(context),
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
            Text(
              _multilocaleTextHelper.getText(context, config.title),
              style: AppTextStyles.heading1.copyWith(
                color: AppColors.backgroundDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Description
            Text(
              _multilocaleTextHelper.getText(context, config.description),
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
              _multilocaleTextHelper.getText(context, config.noteText),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.backgroundDark.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Restore purchases button
            if (config.showRestore) _buildRestoreButton(context),
            // Terms & Privacy links
            _buildTermsAndPrivacyLinks(context),
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
            Text(
              _multilocaleTextHelper.getText(context, config.title),
              style: AppTextStyles.heading2.copyWith(
                color: AppColors.backgroundDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Description
            Text(
              _multilocaleTextHelper.getText(context, config.description),
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
              _multilocaleTextHelper.getText(context, config.noteText),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.backgroundDark.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // Restore purchases button
            if (config.showRestore) _buildRestoreButton(context),
            // Terms & Privacy links
            _buildTermsAndPrivacyLinks(context),
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
                _multilocaleTextHelper.getText(context, config.nextButtonText),
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
                            _multilocaleTextHelper.getText(context, option.title),
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
                              _multilocaleTextHelper.getText(context, option.badge),
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _multilocaleTextHelper.getText(context, option.description),
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

  Widget _buildTermsAndPrivacyLinks(BuildContext context) {
    final remoteConfig = di.sl<RemoteConfigService>();
    final privacyUrl = remoteConfig.getPrivacyPolicyUrl();
    final termsUrl = remoteConfig.getTermsOfUseUrl();

    if (privacyUrl.isEmpty && termsUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (termsUrl.isNotEmpty)
            TextButton(
              onPressed: () => _launchUrl(termsUrl),
              child: Text(
                AppLocalizations.of(context)!.terms,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.backgroundDark.withValues(alpha: 0.6),
                ),
              ),
            ),
          if (privacyUrl.isNotEmpty && termsUrl.isNotEmpty)
            Text(
              ' • ',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.backgroundDark.withValues(alpha: 0.6),
              ),
            ),
          if (privacyUrl.isNotEmpty)
            TextButton(
              onPressed: () => _launchUrl(privacyUrl),
              child: Text(
                AppLocalizations.of(context)!.privacy,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.backgroundDark.withValues(alpha: 0.6),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
