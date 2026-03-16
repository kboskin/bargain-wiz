import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/services/analytics_service.dart';
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/theme/app_text_styles.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/core/widgets/configurable_gradient_background.dart';
import 'package:appwizard/core/widgets/styled_rich_text_description_widget.dart';
import 'package:appwizard/core/widgets/styled_title_widget.dart';
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

class _PaywallPageState extends State<PaywallPage> with TickerProviderStateMixin {
  late AnimationController _timelineAnimationController;
  final List<Animation<double>> _timelineItemAnimations = [];
  PaywallConfig? _paywallConfig;
  String? _selectedOptionId;
  List<SubscriptionProduct> _products = [];
  bool _isLoading = true;
  bool _isPurchasing = false;
  int _currentStepIndex = 0; // For multi-step paywall flows
  bool _stepTransitionForward = true; // true = next, false = back (for animation direction)
  final AppLogger _logger = di.sl<AppLogger>();
  final AnalyticsService _analytics = di.sl<AnalyticsService>();
  final RemoteConfigService _remoteConfigService = di.sl<RemoteConfigService>();

  @override
  void initState() {
    super.initState();
    _loadPaywallConfig();
    _loadProducts();
    _timelineAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void dispose() {
    _timelineAnimationController.dispose();
    super.dispose();
  }

  void _setupTimelineAnimations(int count) {
    if (_timelineItemAnimations.isNotEmpty) return;
    for (int i = 0; i < count; i++) {
      // More spread out intervals for a slower feel
      final start = (i * 0.25).clamp(0.0, 1.0);
      final end = (start + 0.5).clamp(0.0, 1.0);
      _timelineItemAnimations.add(
        CurvedAnimation(
          parent: _timelineAnimationController,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _timelineAnimationController.forward();
      }
    });
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
    if (_products.isEmpty) return null;
    try {
      final tier = option.tierEnum;
      // Using a loop for safer lookup
      for (final p in _products) {
        if (p.tier == tier) return p;
      }
      return null;
    } catch (e) {
      _logger.w('Error looking up product for tier ${option.tier}: $e');
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

  void _onClose() {
    if (context.canPop()) {
      context.pop();
    } else {
      if (kDebugMode) {
        context.go(AppRoutes.main);
      } else {
        context.go(AppRoutes.home);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    );

    if (_isLoading || _paywallConfig == null) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final config = _paywallConfig!;
    final hasSteps = config.steps.isNotEmpty;
    final isOnStep = hasSteps && _currentStepIndex < config.steps.length;
    final showBack = hasSteps && _currentStepIndex > 0;

    final bgConfig = config.background;
    final hasGradient = bgConfig != null &&
        bgConfig.colorObjects.isNotEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
      backgroundColor: hasGradient ? Colors.transparent : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.backgroundDark, size: 22),
                onPressed: () {
                  setState(() {
                    _stepTransitionForward = false;
                    _currentStepIndex--;
                  });
                },
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.backgroundDark),
            onPressed: _onClose,
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (hasGradient)
            Positioned.fill(
              child: ConfigurableGradientBackground(
                colors: bgConfig!.colorObjects,
                stops: bgConfig.stops.length == bgConfig.colorObjects.length
                    ? bgConfig.stops
                    : null,
                child: const SizedBox.shrink(),
              ),
            )
          else
            const ColoredBox(color: Colors.white),
          BlocListener<SubscriptionBloc, SubscriptionState>(
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
        ],
      ),
    ),
    );
  }

  Widget _buildPaywallContent(BuildContext context) {
    final config = _paywallConfig!;
    final hasSteps = config.steps.isNotEmpty;

    // When steps are configured, show them before the main pricing/options
    // screen. Steps are simple explainer screens; the final "step" is the
    // existing paywall UI.
    if (hasSteps && _currentStepIndex < config.steps.length) {
      final step = config.steps[_currentStepIndex];
      return _buildStepLayout(context, config, step);
    }

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

  /// Single step layout (intro / reminder-style screen). Title + visual + description +
  /// "No payment due now" row + CTA that advances to next step or pricing screen.
  Widget _buildStepLayout(
    BuildContext context,
    PaywallConfig config,
    PaywallStepConfig step,
  ) {
    final titleText = _getMultilocaleText(step.title, context);
    final descriptionText = _getMultilocaleText(step.description, context);
    final noteText = _getMultilocaleText(step.noteText, context);
    final stepButtonText = _getMultilocaleText(step.buttonText, context);
    final buttonLabel = (stepButtonText != null && stepButtonText.isNotEmpty)
        ? stepButtonText
        : (_getMultilocaleText(config.nextButtonText, context) ?? AppLocalizations.of(context)!.next);

    final topPadding = MediaQuery.paddingOf(context).top + kToolbarHeight + 24;
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 24;
    final availableHeight = MediaQuery.sizeOf(context).height - topPadding - bottomPadding;

    return Padding(
      padding: EdgeInsets.only(top: topPadding, left: 24, right: 24, bottom: bottomPadding),
      child: SizedBox(
        height: availableHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (titleText != null && titleText.isNotEmpty)
                  StyledTitleWidget(
                    title: titleText,
                    highlightWordsData: step.titleHighlightWords?.description,
                    highlightColor: step.highlightColor,
                    baseColor: AppColors.backgroundDark,
                    fontSize: 26,
                    fontSizeHighlight: 28,
                  ),
                if (titleText != null && titleText.isNotEmpty) const SizedBox(height: 20),
                if (step.visual != null && step.visual!.isNotEmpty) ...[
                  VisualAssetWidget(
                    visualPath: step.visual!,
                    width: 260,
                    height: 260,
                  ),
                  const SizedBox(height: 20),
                ],
                if (descriptionText != null && descriptionText.isNotEmpty)
                  Text(
                    descriptionText,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.backgroundDark.withValues(alpha: 0.85),
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildNoPaymentDueNow(context, config),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _stepTransitionForward = true;
                        _currentStepIndex++;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.backgroundDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(buttonLabel, style: AppTextStyles.buttonText),
                  ),
                ),
                if (noteText != null && noteText.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    noteText,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.backgroundDark.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _getMultilocaleText(dynamic ml, BuildContext context) {
    if (ml == null) return null;
    if (ml is String) return ml.isEmpty ? null : ml;
    try {
      final s = (ml as dynamic).get(context) as String?;
      return s?.isEmpty == true ? null : s;
    } catch (_) {
      return ml.toString();
    }
  }

  /// "No payment due now" row with checkmark, shown above the main CTA on all screens.
  /// Uses [StyledRichTextDescriptionWidget] so the line can support highlight words via config later.
  Widget _buildNoPaymentDueNow(BuildContext context, PaywallConfig config) {
    final text = _getMultilocaleText(config.noPaymentDueText, context) ?? 'No payment due now';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, size: 20, color: AppColors.backgroundDark),
        const SizedBox(width: 8),
        StyledRichTextDescriptionWidget(
          description: text,
          highlightWordsData: config.noPaymentHighlightWords?.description ?? const {},
          baseColor: AppColors.backgroundDark,
          bodyFontSize: 16,
          baseColorOpacity: 1.0,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Vertical timeline for trial: Today (unlock), In N days (reminder), In trialDays (billing starts).

  Widget _buildTrialTimeline(BuildContext context, PaywallConfig config) {
    final days = config.trialDays.clamp(1, 365);
    final now = DateTime.now();
    final billingDate = now.add(Duration(days: days));
    final billingStr = '${billingDate.day} ${_monthName(billingDate.month)} ${billingDate.year}';
    final colorTrial = const Color(0xFFFF9800);
    final colorBilling = AppColors.backgroundDark;

    _setupTimelineAnimations(3);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnimatedTimelineRow(
            0,
            icon: Icons.lock_open,
            iconColor: colorTrial,
            title: _getMultilocaleText(config.timelineTodayText, context) ?? 'Today',
            subtitle: _getMultilocaleText(config.timelineTodaySubtitle, context) ?? "Unlock all the app's features.",
            nextColor: colorTrial,
          ),
          _buildAnimatedTimelineRow(
            1,
            icon: Icons.notifications_active,
            iconColor: colorTrial,
            title: _getMultilocaleText(config.timelineReminderText, context) ?? (days > 1 ? 'In ${days - 1} day${days == 2 ? '' : 's'} – Reminder' : 'Reminder'),
            subtitle: _getMultilocaleText(config.timelineReminderSubtitle, context) ?? "We'll send you a reminder that your trial is ending soon.",
            nextColor: colorBilling,
          ),
          _buildAnimatedTimelineRow(
            2,
            icon: Icons.workspace_premium,
            iconColor: colorBilling,
            title: _getMultilocaleText(config.timelineBillingText, context) ?? 'In $days days – Billing starts',
            subtitle: _getMultilocaleText(config.timelineBillingSubtitle, context) ?? "You'll be charged on $billingStr unless you cancel before.",
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedTimelineRow(
    int index, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Color? nextColor,
    bool isLast = false,
  }) {
    final animation = _timelineItemAnimations[index];
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: _timelineRow(
        context,
        icon: icon,
        iconColor: iconColor,
        title: title,
        subtitle: subtitle,
        nextColor: nextColor,
        isLast: isLast,
      ),
    );
  }

  String _monthName(int month) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[(month - 1).clamp(0, 11)];
  }

  Widget _timelineRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Color? nextColor,
    bool isLast = false,
    int index = 0,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Connecting lines
                Column(
                  children: [
                    // Line coming from above (except for first item)
                    Expanded(
                      child: Container(
                        width: 6,
                        color: index == 0 ? Colors.transparent : iconColor,
                      ),
                    ),
                    // Space where the circle sits
                    const SizedBox(height: 36),
                    // Line going below (except for last item)
                    Expanded(
                      child: Container(
                        width: 6,
                        decoration: BoxDecoration(
                          gradient: isLast
                              ? null
                              : LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    iconColor,
                                    iconColor,
                                    nextColor ?? iconColor,
                                    nextColor ?? iconColor,
                                  ],
                                  stops: const [0.0, 0.4, 0.6, 1.0],
                                ),
                          color: isLast ? Colors.transparent : null,
                        ),
                      ),
                    ),
                  ],
                ),
                // The actual icon circle, centered to the IntrinsicHeight of the row
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white, // Background to cover the line
                    border: Border.all(color: iconColor, width: 2),
                  ),
                  child: Center(
                    child: Container(
                      width: 30, // Inner circle
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: iconColor.withValues(alpha: 0.15),
                      ),
                      child: Icon(icon, size: 18, color: iconColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center, // Center text block vertically
                children: [
                  Text(
                    title,
                    style: AppTextStyles.heading3.copyWith(
                      color: AppColors.backgroundDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.backgroundDark.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Layout methods (reusing the same logic roughly)

  Widget _buildCardsLayout(
    BuildContext context,
    PaywallConfig config,
    PaywallOption selectedOption,
  ) {
    final topPadding = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 24;
    final availableHeight = MediaQuery.sizeOf(context).height - topPadding - bottomPadding;

    return Padding(
      padding: EdgeInsets.only(top: topPadding, left: 24, right: 24, bottom: bottomPadding),
      child: SizedBox(
        height: availableHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StyledTitleWidget(
                  title: _getMultilocaleText(config.title, context) ?? '',
                  highlightWordsData: config.titleHighlightWords?.description ?? const {},
                  highlightColor: config.metadata.highlightColor,
                  baseColor: AppColors.backgroundDark,
                  fontSize: 34,
                  fontSizeHighlight: 38,
                ),
                const SizedBox(height: 16),
                StyledRichTextDescriptionWidget(
                  description: _getMultilocaleText(config.description, context) ?? '',
                  highlightWordsData: config.descriptionHighlightWords?.description ?? const {},
                  baseColor: AppColors.backgroundDark,
                  baseColorOpacity: 0.7,
                  bodyFontSize: 16,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (config.trialDays >= 1) _buildTrialTimeline(context, config),
                ...config.options.map((option) => _buildOptionCard(
                      context,
                      option,
                      config,
                      isSelected: option.id == _selectedOptionId,
                    )),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildNoPaymentDueNow(context, config),
                const SizedBox(height: 4),
                _buildCtaButton(context, config, selectedOption),
                const SizedBox(height: 12),
                Text(
                  _getMultilocaleText(config.noteText, context) ?? '',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.backgroundDark.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
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
    final topPadding = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 24;
    final availableHeight = MediaQuery.sizeOf(context).height - topPadding - bottomPadding;

    return Padding(
      padding: EdgeInsets.only(top: topPadding, left: 24, right: 24, bottom: bottomPadding),
      child: SizedBox(
        height: availableHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StyledTitleWidget(
                  title: _getMultilocaleText(config.title, context) ?? '',
                  highlightWordsData: config.titleHighlightWords?.description ?? const {},
                  highlightColor: config.metadata.highlightColor,
                  baseColor: AppColors.backgroundDark,
                  fontSize: 34,
                  fontSizeHighlight: 38,
                ),
                const SizedBox(height: 16),
                StyledRichTextDescriptionWidget(
                  description: _getMultilocaleText(config.description, context) ?? '',
                  highlightWordsData: config.descriptionHighlightWords?.description ?? const {},
                  baseColor: AppColors.backgroundDark,
                  baseColorOpacity: 0.7,
                  bodyFontSize: 16,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (config.trialDays >= 1) _buildTrialTimeline(context, config),
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
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildNoPaymentDueNow(context, config),
                const SizedBox(height: 4),
                _buildCtaButton(context, config, selectedOption),
                const SizedBox(height: 12),
                Text(
                  _getMultilocaleText(config.noteText, context) ?? '',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.backgroundDark.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
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
    final topPadding = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 24;
    final availableHeight = MediaQuery.sizeOf(context).height - topPadding - bottomPadding;

    return Padding(
      padding: EdgeInsets.only(top: topPadding, left: 24, right: 24, bottom: bottomPadding),
      child: SizedBox(
        height: availableHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StyledTitleWidget(
                  title: _getMultilocaleText(config.title, context) ?? '',
                  highlightWordsData: config.titleHighlightWords?.description ?? const {},
                  highlightColor: config.metadata.highlightColor,
                  baseColor: AppColors.backgroundDark,
                  fontSize: 28,
                  fontSizeHighlight: 32,
                ),
                const SizedBox(height: 8),
                StyledRichTextDescriptionWidget(
                  description: _getMultilocaleText(config.description, context) ?? '',
                  highlightWordsData: config.descriptionHighlightWords?.description ?? const {},
                  baseColor: AppColors.backgroundDark,
                  baseColorOpacity: 0.7,
                  bodyFontSize: 14,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (config.trialDays >= 1) _buildTrialTimeline(context, config),
                ...config.options.map((option) => _buildOptionCard(
                      context,
                      option,
                      config,
                      isSelected: option.id == _selectedOptionId,
                      compact: true,
                    )),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildNoPaymentDueNow(context, config),
                const SizedBox(height: 4),
                _buildCtaButton(context, config, selectedOption),
                const SizedBox(height: 12),
                Text(
                  _getMultilocaleText(config.noteText, context) ?? '',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.backgroundDark.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
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
                _getMultilocaleText(config.nextButtonText, context) ?? '',
                style: AppTextStyles.buttonText,
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
        repeat: metadata.isAnimationLooped,
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
                              _getMultilocaleText(option.title, context) ?? '',
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
                              _getMultilocaleText(option.badge, context) ?? '',
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getMultilocaleText(option.description, context) ?? '',
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

}
