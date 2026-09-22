import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/routing/app_routes.dart';
import 'package:appwizard/core/services/analytics_service.dart';
import 'package:appwizard/core/services/feature_gate_service.dart';
import 'package:appwizard/core/services/firebase_service.dart';
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/configurable_gradient_background.dart';
import 'package:appwizard/core/widgets/wiz/fade_up.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/core/widgets/wiz/wiz_toast.dart';
import 'package:appwizard/features/paywall/data/models/paywall_config.dart';
import 'package:appwizard/features/paywall/domain/paywall_args.dart';
import 'package:appwizard/features/paywall/domain/paywall_copy.dart';
import 'package:appwizard/features/paywall/presentation/widgets/paywall_plan_layouts.dart';
import 'package:appwizard/features/paywall/presentation/widgets/paywall_step_view.dart';
import 'package:appwizard/features/paywall/presentation/widgets/paywall_timeline.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_product.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_status.dart';
import 'package:appwizard/features/subscription/presentation/bloc/subscription_bloc.dart';
import 'package:appwizard/features/subscription/presentation/bloc/subscription_event.dart';
import 'package:appwizard/features/subscription/presentation/bloc/subscription_state.dart';
import 'package:appwizard/l10n/app_localizations.dart';

/// Full-screen paywall modal (design handoff §7): optional explainer steps, then the plans
/// step (cards / list / compact) with the monthly / weekly options of the one paid plan. The
/// trial timeline only renders when a trial is configured.
///
/// Pops with `true` when access is granted (purchase, restore or debug override) and
/// `false` when closed. Open it through [PaywallLauncher]; requires a [SubscriptionBloc]
/// above it (provided by the router).
class PaywallPage extends StatefulWidget {
  const PaywallPage({
    super.key,
    this.paywallKey = 'paywall_config',
    this.args = const PaywallArgs(),
  });

  final String paywallKey;
  /// Entry context (hint + preselected plan).
  final PaywallArgs args;

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  final AppLogger _logger = di.sl<AppLogger>();
  final AnalyticsService _analytics = di.sl<AnalyticsService>();
  final RemoteConfigService _remoteConfig = di.sl<RemoteConfigService>();
  final FeatureGateService _gate = di.sl<FeatureGateService>();

  PaywallConfig? _config;
  bool _loading = true;

  int _stepIndex = 0;
  bool _forward = true;
  bool _advancing = false;

  String? _selectedId;
  List<SubscriptionProduct> _products = const [];

  bool _purchasing = false;
  bool _restoring = false;
  bool _purchaseFailed = false;

  bool _closeVisible = false;
  Timer? _closeTimer;
  /// Resets the CTA if the store never answers (no billing on emulators / sideloads).
  Timer? _purchaseWatchdog;
  static const Duration _purchaseTimeout = Duration(seconds: 45);

  @override
  void initState() {
    super.initState();
    _loadConfig();
    context.read<SubscriptionBloc>().add(const LoadProductsRequested());
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _purchaseWatchdog?.cancel();
    super.dispose();
  }

  void _armPurchaseWatchdog() {
    _purchaseWatchdog?.cancel();
    _purchaseWatchdog = Timer(_purchaseTimeout, () {
      if (!mounted || !_purchasing) return;
      setState(() {
        _purchasing = false;
        _purchaseFailed = true;
      });
      WizToast.show(context, 'The store did not respond. Please try again.');
    });
  }

  // ── setup ────────────────────────────────────────────────────────────────

  void _loadConfig() {
    try {
      final config = _remoteConfig.getPaywallConfig(configKey: widget.paywallKey);
      if (config == null) {
        _logger.w('PaywallPage: no config for ${widget.paywallKey}');
      } else {
        _config = config;
        _selectedId = _initialSelection(config);
        _scheduleClose(config);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _analytics.logPaywallImpression(paywallType: config.type);
        });
      }
    } catch (e, st) {
      _logger.e('PaywallPage: error loading config', e, st);
    }
    _loading = false;
  }

  String? _initialSelection(PaywallConfig config) {
    final ids = config.options.map((o) => o.id).toSet();
    final wanted = widget.args.preselectOptionId;
    if (wanted != null && ids.contains(wanted)) return wanted;
    if (ids.contains(config.metadata.defaultSelectedOptionId)) {
      return config.metadata.defaultSelectedOptionId;
    }
    return config.options.isEmpty ? null : config.options.first.id;
  }

  void _scheduleClose(PaywallConfig config) {
    if (!config.showClose) return;
    final seconds = config.closeButtonDelaySeconds;
    if (seconds <= 0) {
      _closeVisible = true;
      return;
    }
    _closeTimer = Timer(Duration(milliseconds: (seconds * 1000).round()), () {
      if (mounted) setState(() => _closeVisible = true);
    });
  }

  // ── derived ──────────────────────────────────────────────────────────────

  PaywallOption? get _selectedOption {
    final c = _config;
    if (c == null || c.options.isEmpty) return null;
    return c.options.where((o) => o.id == _selectedId).firstOrNull ?? c.options.first;
  }

  bool get _onPlansStep => _config != null && _stepIndex >= _config!.steps.length;

  /// Store price → `price_label` → null (hidden).
  String? priceFor(PaywallOption option) =>
      PaywallPricing.priceFor(option, _products, resolve: (v) => TemplateText.textOf(context, v));

  /// QA shortcut: available in debug/dev builds when the store cannot serve the purchase.
  bool get _debugShortcutAvailable {
    // Debug / dev builds only. Always offered there so QA can walk every gate on
    // emulators and sideloads where the store never answers.
    if (!_gate.canOverride) return false;
    return _selectedOption != null;
  }

  AppLocalizations? get _l10n => AppLocalizations.of(context);

  // ── actions ──────────────────────────────────────────────────────────────

  void _close() {
    if (context.canPop()) {
      context.pop(false);
    } else {
      context.go(AppRoutes.home);
    }
  }

  void _grantAccess(String toast) {
    WizToast.show(context, toast);
    _gate.invalidate();
    if (context.canPop()) {
      context.pop(true);
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _continueStep(PaywallStepConfig step) async {
    if (_advancing) return;
    setState(() => _advancing = true);
    if (step.asksNotificationPermission) {
      // The reminder step is where we ask for push (handoff decision). Same call the
      // onboarding permission screen makes, so both opt-ins register FCM the one way;
      // it never throws and returns null when messaging is unavailable.
      final settings = await FirebaseService.requestNotificationPermission();
      if (settings == null) {
        _logger.w('PaywallPage: notification permission could not be requested');
      }
    }
    if (!mounted) return;
    setState(() {
      _advancing = false;
      _forward = true;
      _stepIndex++;
    });
  }

  void _select(PaywallOption option) {
    if (option.id == _selectedId) return;
    setState(() => _selectedId = option.id);
    final c = _config;
    if (c != null) {
      _analytics.logPaywallOptionSelected(
        paywallType: c.type,
        optionId: option.id,
        tier: option.tier,
      );
    }
  }

  void _purchase() {
    final c = _config;
    final option = _selectedOption;
    if (c == null || option == null || _purchasing) return;
    final productId = PaywallPricing.productIdFor(option, _products);
    if (productId == null) {
      setState(() => _purchaseFailed = true);
      WizToast.show(context, _l10n?.productNotAvailable ?? 'Product not available');
      return;
    }
    _analytics.logPaywallCtaTap(
      paywallType: c.type,
      tier: option.tier,
      additionalParams: {'option_id': option.id},
    );
    setState(() => _purchasing = true);
    _armPurchaseWatchdog();
    context.read<SubscriptionBloc>().add(PurchaseSubscriptionRequested(productId));
  }

  void _debugActivate() {
    final option = _selectedOption;
    if (option == null || !_debugShortcutAvailable) return;
    _gate.setDebugOverride(option.tierEnum);
    _grantAccess('Debug: ${option.tier} tier enabled');
  }

  void _restore() {
    if (_restoring || _purchasing) return;
    setState(() => _restoring = true);
    context.read<SubscriptionBloc>().add(const RestorePurchasesRequested());
  }

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _logger.w('PaywallPage: could not open $url: $e');
    }
  }

  // ── bloc ─────────────────────────────────────────────────────────────────

  void _onSubscriptionState(BuildContext context, SubscriptionState state) {
    final c = _config;
    final option = _selectedOption;
    if (state is ProductsLoaded) {
      setState(() => _products = state.products);
    } else if (state is PurchaseInProgress) {
      if (!_purchasing) setState(() => _purchasing = true);
    } else if (state is PurchaseSuccess) {
      _purchaseWatchdog?.cancel();
      setState(() => _purchasing = false);
      if (c != null && option != null) {
        _analytics.logEvent(
          name: 'purchase_success',
          parameters: {'paywall_type': c.type, 'tier': option.tier, 'option_id': option.id},
        );
      }
      _grantAccess(_l10n?.subscriptionActivated ?? 'Subscription activated!');
    } else if (state is PurchaseError) {
      _purchaseWatchdog?.cancel();
      final wasRestoring = _restoring;
      setState(() {
        _purchasing = false;
        _restoring = false;
        if (!wasRestoring) _purchaseFailed = true;
      });
      if (c != null && option != null && !wasRestoring) {
        _analytics.logEvent(
          name: 'purchase_fail',
          parameters: {
            'paywall_type': c.type,
            'tier': option.tier,
            'option_id': option.id,
            'error': state.message,
          },
        );
      }
      WizToast.show(context, state.message);
    } else if (state is StatusChecked && _restoring) {
      setState(() => _restoring = false);
      final SubscriptionStatus? status = state.status;
      if (status != null && status.isActive && !status.isExpired()) {
        _grantAccess('Purchases restored');
      } else {
        WizToast.show(context, 'No active subscription found');
      }
    }
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    );

    final config = _config;
    if (_loading || config == null) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: _loading
                ? const CircularProgressIndicator(color: WizColors.ink)
                : _ConfigMissing(onClose: _close),
          ),
        ),
      );
    }

    final bg = config.background;
    final bgColors = bg?.colorObjects ?? const <Color>[];

    Widget body = SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(WizSpacing.gutter, 0, WizSpacing.gutter, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 36,
              child: Align(
                alignment: Alignment.centerRight,
                child: _closeVisible ? FadeUp(child: _CloseButton(onPressed: _close)) : null,
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final incoming = child.key == ValueKey<int>(_stepIndex);
                  final dx = (_forward ? 1 : -1) * (incoming ? 1.0 : -1.0) * 0.06;
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: Offset(dx, 0), end: Offset.zero)
                          .animate(animation),
                      child: child,
                    ),
                  );
                },
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: [...previous, if (current != null) current],
                ),
                child: KeyedSubtree(
                  key: ValueKey<int>(_stepIndex),
                  child: _onPlansStep ? _buildPlans(config) : _buildStep(config),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (bgColors.length >= 2) {
      body = ConfigurableGradientBackground(
        colors: bgColors,
        stops: bg!.stops.length == bgColors.length ? bg.stops : null,
        child: body,
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: bgColors.length == 1 ? bgColors.first : Colors.white,
        body: BlocListener<SubscriptionBloc, SubscriptionState>(
          listener: _onSubscriptionState,
          child: body,
        ),
      ),
    );
  }

  Widget _buildStep(PaywallConfig config) {
    final step = config.steps[_stepIndex];
    final label = TemplateText.textOf(
      context,
      step.buttonText,
      fallback: TemplateText.textOf(context, config.nextButtonText, fallback: 'Continue'),
    );
    return PaywallStepView(
      step: step,
      buttonLabel: label,
      busy: _advancing,
      onContinue: () => _continueStep(step),
    );
  }

  Widget _buildPlans(PaywallConfig config) {
    final option = _selectedOption;
    final title = TemplateText.textOf(context, config.title, fallback: 'Unlock Bargain Wiz');
    final description = TemplateText.textOf(context, config.description);
    final hint = PaywallHints.hintFor(config.contextHints, widget.args.entry);
    final hintText = hint == null ? '' : hint.get(context);
    final planTitle = option == null ? '' : TemplateText.textOf(context, option.title);
    final price = option == null ? null : priceFor(option);
    final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag();
    final rows = PaywallTimelineBuilder.build(
      config: config,
      now: DateTime.now(),
      plan: planTitle,
      price: price,
      resolve: (v) => TemplateText.textOf(context, v),
      locale: locale,
    );
    final ctaLabel = TemplateText.textOf(context, config.nextButtonText, fallback: 'Unlock Bargain Wiz');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 4),
            child: FadeUp(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, textAlign: TextAlign.center, style: WizType.title),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(description, textAlign: TextAlign.center, style: WizType.bodyMd),
                  ],
                  const SizedBox(height: 16),
                  if (hintText.isNotEmpty) ...[
                    _ContextHint(text: hintText),
                    const SizedBox(height: 12),
                  ],
                  PaywallPlanPicker(
                    config: config,
                    selectedId: _selectedId,
                    priceFor: priceFor,
                    onSelect: _select,
                  ),
                  if (rows.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
                      child: PaywallTimeline(
                        // Re-run the entrance only when the row set changes, not on reselection.
                        key: ValueKey<int>(rows.length),
                        rows: rows,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        _NoteText(
          template: TemplateText.textOf(
            context,
            config.noteText,
            fallback: '{price}, renews automatically. Cancel anytime.',
          ),
          price: price,
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onLongPress: _debugShortcutAvailable ? _debugActivate : null,
          child: WizPrimaryButton(
            label: ctaLabel,
            loading: _purchasing || _restoring,
            onPressed: option == null ? null : _purchase,
          ),
        ),
        if (_debugShortcutAvailable) ...[
          const SizedBox(height: 6),
          Text(
            _purchaseFailed
                ? 'store unavailable · long-press to activate ${option?.tier ?? ''} for QA'
                : 'debug · long-press to activate ${option?.tier ?? ''} without the store',
            textAlign: TextAlign.center,
            style: WizType.footnote.copyWith(fontSize: 11),
          ),
        ],
        const SizedBox(height: 12),
        _FooterLinks(
          showRestore: config.showRestore,
          restoreLabel: _l10n?.restorePurchases ?? 'Restore Purchases',
          termsLabel: _l10n?.terms ?? 'Terms',
          privacyLabel: _l10n?.privacy ?? 'Privacy',
          onRestore: _restore,
          onTerms: () => _openUrl(_remoteConfig.getTermsOfUseUrl()),
          onPrivacy: () => _openUrl(_remoteConfig.getPrivacyPolicyUrl()),
        ),
      ],
    );
  }
}

// ── pieces ─────────────────────────────────────────────────────────────────

/// 34px ✕ in a segment-track circle, top-right.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => WizRoundIconButton(
        icon: Icons.close_rounded,
        size: 34,
        iconSize: 18,
        color: WizColors.segmentTrack,
        iconColor: WizColors.textSecondary,
        onPressed: onPressed,
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
      );
}

class _ContextHint extends StatelessWidget {
  const _ContextHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: WizColors.amberSoft,
          borderRadius: BorderRadius.circular(WizRadii.thumbLg),
        ),
        child: Text(
          text,
          style: WizType.captionMedium.copyWith(color: WizColors.amberInk, height: 1.35),
        ),
      );
}

/// "**$19.99/mo**, renews automatically. Cancel anytime." — `{price}` rendered bold.
class _NoteText extends StatelessWidget {
  const _NoteText({required this.template, required this.price});

  final String template;
  final String? price;

  @override
  Widget build(BuildContext context) {
    final base = WizType.captionMedium.copyWith(color: WizColors.textSecondary, fontSize: 12.5);
    final bold = base.copyWith(color: WizColors.ink, fontWeight: FontWeight.w700);
    const token = '{price}';
    final idx = template.indexOf(token);
    final spans = <InlineSpan>[];
    if (idx < 0 || price == null || price!.isEmpty) {
      spans.add(TextSpan(text: TemplateText.fill(template, {'price': price ?? ''}).trim()));
    } else {
      spans.add(TextSpan(text: template.substring(0, idx)));
      spans.add(TextSpan(text: price, style: bold));
      spans.add(TextSpan(text: template.substring(idx + token.length)));
    }
    return Text.rich(TextSpan(style: base, children: spans), textAlign: TextAlign.center);
  }
}

class _FooterLinks extends StatelessWidget {
  const _FooterLinks({
    required this.showRestore,
    required this.restoreLabel,
    required this.termsLabel,
    required this.privacyLabel,
    required this.onRestore,
    required this.onTerms,
    required this.onPrivacy,
  });

  final bool showRestore;
  final String restoreLabel;
  final String termsLabel;
  final String privacyLabel;
  final VoidCallback onRestore;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    final style = WizType.footnote.copyWith(fontWeight: FontWeight.w500);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showRestore) ...[
          WizTextLink(
            label: restoreLabel,
            onPressed: onRestore,
            color: WizColors.textTertiary,
            underline: true,
            style: style,
          ),
          const SizedBox(width: 12),
        ],
        WizTextLink(label: termsLabel, onPressed: onTerms, color: WizColors.textTertiary, style: style),
        const SizedBox(width: 12),
        WizTextLink(label: privacyLabel, onPressed: onPrivacy, color: WizColors.textTertiary, style: style),
      ],
    );
  }
}

class _ConfigMissing extends StatelessWidget {
  const _ConfigMissing({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(WizSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Plans are unavailable right now.', style: WizType.bodySecondary),
            const SizedBox(height: 16),
            WizSecondaryButton(label: 'Close', onPressed: onClose, expand: false),
          ],
        ),
      );
}
