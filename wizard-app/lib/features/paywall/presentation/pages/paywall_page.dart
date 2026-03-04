import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/services/analytics_service.dart';
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/theme/app_text_styles.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/core/routing/app_routes.dart';
import 'package:appwizard/features/paywall/data/models/paywall_config.dart';
import 'package:appwizard/features/paywall/data/models/paywall_layout.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_product.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';
import 'package:appwizard/l10n/app_localizations.dart';
import 'package:appwizard/features/subscription/presentation/bloc/subscription_bloc.dart';
import 'package:appwizard/features/subscription/presentation/bloc/subscription_event.dart';
import 'package:appwizard/features/subscription/presentation/bloc/subscription_state.dart';

class PaywallPage extends StatefulWidget {
  final String paywallKey;

  const PaywallPage({
    super.key,
    this.paywallKey = 'paywall_config',
  });

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  PaywallConfig? _paywallConfig;
  String? _selectedOptionId;
  List<SubscriptionProduct> _products = [];
  bool _isLoading = true;
  bool _isPurchasing = false;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_paywallConfig != null && !_isLoading) {
      _analytics.logPaywallImpression(
        paywallType: _paywallConfig!.type,
      );
    }
  }

  Future<void> _loadPaywallConfig() async {
    try {
      final config = _remoteConfigService.getPaywallConfig(
        configKey: widget.paywallKey,
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
    if (_products.isEmpty) return null;
    try {
      final product = _products.firstWhere(
        (p) => p.tier == tier,
        orElse: () => _products.first,
      );
      return product.productId;
    } catch (e) {
      _logger.w('Product not found for tier $tier: $e');
      return null;
    }
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

  void _onClose() {
    if (kDebugMode) {
      context.go(AppRoutes.main);
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _paywallConfig == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white, // Or theme background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.backgroundDark),
            onPressed: _onClose,
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: BlocListener<SubscriptionBloc, SubscriptionState>(
        listener: (context, state) {
          if (state is PurchaseSuccess) {
            setState(() {
              _isPurchasing = false;
            });
            
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
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.subscriptionActivated),
                backgroundColor: Colors.green,
              ),
            );
            
            // Navigate home handled by listener logic in app usually, but we force it here
            context.go(AppRoutes.home);
            
          } else if (state is PurchaseError) {
            setState(() {
              _isPurchasing = false;
            });
            
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
              if (_paywallConfig != null && _selectedOptionId != null) {
                final currentOption = _paywallConfig!.options.firstWhere(
                  (opt) => opt.id == _selectedOptionId,
                  orElse: () => _paywallConfig!.options.first,
                );
                final currentProduct = _getProductForOption(currentOption);
                if (currentProduct == null && _products.isNotEmpty) {
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
        child: _buildPaywallContent(context),
      ),
    );
  }

  Widget _buildPaywallContent(BuildContext context) {
    final config = _paywallConfig!;
    final selectedOption = config.options.firstWhere(
      (opt) => opt.id == _selectedOptionId,
      orElse: () => config.options.first,
    );

    switch (config.metadata.layout) {
      case PaywallLayout.cards:
        return _buildCardsLayout(context, config, selectedOption);
      case PaywallLayout.list:
        return _buildListLayout(context, config, selectedOption);
      case PaywallLayout.compact:
        return _buildCompactLayout(context, config, selectedOption);
    }
  }

  // Layout methods (reusing the same logic roughly)

  Widget _buildCardsLayout(
    BuildContext context,
    PaywallConfig config,
    PaywallOption selectedOption,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(top: kToolbarHeight + 20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
            Text(
              config.title.get(context),
              style: AppTextStyles.heading1.copyWith(
                color: AppColors.backgroundDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              config.description.get(context),
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.backgroundDark.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildVisual(selectedOption.id, config.metadata),
            const SizedBox(height: 32),
            ...config.options.map((option) => _buildOptionCard(
                  context,
                  option,
                  config,
                  isSelected: option.id == _selectedOptionId,
                )),
            const SizedBox(height: 24),
            _buildCtaButton(context, config, selectedOption),
            const SizedBox(height: 12),
            Text(
              config.noteText.get(context),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.backgroundDark.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (config.showRestore) _buildRestoreButton(context),
            _buildTermsAndPrivacyLinks(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildListLayout(
    BuildContext context,
    PaywallConfig config,
    PaywallOption selectedOption,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(top: kToolbarHeight + 20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
            Text(
              config.title.get(context),
              style: AppTextStyles.heading1.copyWith(
                color: AppColors.backgroundDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              config.description.get(context),
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.backgroundDark.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildVisual(selectedOption.id, config.metadata),
            const SizedBox(height: 24),
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
            _buildCtaButton(context, config, selectedOption),
            const SizedBox(height: 12),
            Text(
              config.noteText.get(context),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.backgroundDark.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (config.showRestore) _buildRestoreButton(context),
            _buildTermsAndPrivacyLinks(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactLayout(
    BuildContext context,
    PaywallConfig config,
    PaywallOption selectedOption,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(top: kToolbarHeight + 20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
            Text(
              config.title.get(context),
              style: AppTextStyles.heading2.copyWith(
                color: AppColors.backgroundDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              config.description.get(context),
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.backgroundDark.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildVisual(selectedOption.id, config.metadata),
            const SizedBox(height: 16),
            ...config.options.map((option) => _buildOptionCard(
                  context,
                  option,
                  config,
                  isSelected: option.id == _selectedOptionId,
                  compact: true,
                )),
            const SizedBox(height: 16),
            _buildCtaButton(context, config, selectedOption),
            const SizedBox(height: 8),
            Text(
              config.noteText.get(context),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.backgroundDark.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (config.showRestore) _buildRestoreButton(context),
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
