import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/routing/app_routes.dart';
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/services/user_profile_service.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/configurable_gradient_background.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_screen_config.dart';
import 'package:appwizard/features/onboarding/domain/logic/onboarding_profile_snapshot.dart';
import 'package:appwizard/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:appwizard/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:appwizard/features/onboarding/presentation/bloc/onboarding_event.dart';
import 'package:appwizard/features/onboarding/presentation/bloc/onboarding_state.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/create_account_screen_widget.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/data_upload_screen_widget.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/engagement_screen_widget.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/image_list_screen_widget.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/multi_select_screen_widget.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/onboarding_text.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/paywall_screen_widget.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/permission_screen_widget.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/referral_code_screen_widget.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/select_group_screen_widget.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/select_screen_widget.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/slider_lottie_screen_widget.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/slider_screen_widget.dart';
import 'package:appwizard/features/onboarding/presentation/pages/widgets/warmup_screen_widget.dart';
import 'package:appwizard/features/paywall/presentation/paywall_launcher.dart';
import 'package:appwizard/features/subscription/presentation/bloc/subscription_bloc.dart';
import 'package:appwizard/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Onboarding flow: remote-configured screen list rendered in the redesign shell
/// (top bar with progress + step counter, per-screen template, bottom CTA).
class OnboardingFlowPage extends StatelessWidget {
  const OnboardingFlowPage({super.key});

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => di.sl<OnboardingBloc>()..add(const LoadOnboardingConfigRequested()),
          ),
          BlocProvider(create: (_) => di.sl<SubscriptionBloc>()),
        ],
        child: const _OnboardingFlowView(),
      );
}

class _OnboardingFlowView extends StatefulWidget {
  const _OnboardingFlowView();

  @override
  State<_OnboardingFlowView> createState() => _OnboardingFlowViewState();
}

class _OnboardingFlowViewState extends State<_OnboardingFlowView> {
  final PageController _pageController = PageController();
  int _index = 0;

  /// Screens whose option the user explicitly tapped (for `require_explicit_tap`).
  final Set<int> _tapped = {};

  /// Upload started for the data_upload page (created once per activation).
  Future<void>? _uploadFuture;
  int? _uploadForIndex;
  bool _paywallOpen = false;

  OnboardingBloc get _bloc => context.read<OnboardingBloc>();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ─── navigation ────────────────────────────────────────────────────────────

  Future<void> _goTo(OnboardingConfigLoaded state, int target, {required bool forward}) async {
    final screens = state.screens;
    if (target >= screens.length) {
      _bloc.add(const SubmitOnboardingRequested());
      return;
    }
    if (target < 0) {
      if (context.canPop()) context.pop();
      return;
    }
    final screen = screens[target];
    if (screen.type == OnboardingScreenType.paywall) {
      // Retired template: open the paywall route and advance regardless of the result.
      if (forward) await _openPaywall();
      if (!mounted) return;
      await _goTo(state, forward ? target + 1 : target - 1, forward: forward);
      return;
    }
    if (!mounted) return;
    setState(() => _index = target);
    final current = _pageController.hasClients ? (_pageController.page?.round() ?? _index) : _index;
    if (!_pageController.hasClients || (target - current).abs() > 1) {
      _pageController.jumpToPage(target);
    } else {
      await _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _openPaywall() async {
    if (_paywallOpen) return;
    _paywallOpen = true;
    try {
      await PaywallLauncher.open(context, entry: PaywallEntry.onboarding);
    } finally {
      _paywallOpen = false;
    }
  }

  void _next(OnboardingConfigLoaded state) {
    FocusScope.of(context).unfocus();
    if (_index >= state.screens.length) return;
    if (!_isValid(state.screens[_index], state.answers[_index])) return;
    _goTo(state, _index + 1, forward: true);
  }

  void _back(OnboardingConfigLoaded state) {
    FocusScope.of(context).unfocus();
    _goTo(state, _index - 1, forward: false);
  }

  void _answer(int index, dynamic value) =>
      _bloc.add(OnboardingAnswerChanged(screenIndex: index, answer: value));

  // ─── validation ────────────────────────────────────────────────────────────

  bool _isValid(OnboardingModel screen, dynamic answer) => screen.when<bool>(
        multiSelect: (m) => answer is List && answer.length >= m.minSelected,
        select: (m) => answer != null && (!m.requireExplicitTap || _tapped.contains(_index)),
        selectGroup: (m) =>
            answer is Map && m.groups.every((g) => answer[g.answerKeyName] != null && '${answer[g.answerKeyName]}'.isNotEmpty),
        slider: (_) => answer != null,
        sliderLottie: (_) => answer != null,
        referralCode: (_) => true,
        engagement: (_) => true,
        permission: (_) => true,
        imageList: (_) => true,
        paywall: (_) => true,
        warmup: (_) => true,
        dataUpload: (_) => true,
        createAccount: (_) => true,
      );

  bool _showsCta(OnboardingModel screen) {
    if (!screen.showNextButton) return false;
    switch (screen.type) {
      case OnboardingScreenType.dataUpload:
      case OnboardingScreenType.permission:
      case OnboardingScreenType.paywall:
        return false;
      default:
        return true;
    }
  }

  String _ctaText(BuildContext context, OnboardingModel screen, int total) {
    final configured = TemplateText.textOf(context, screen.nextButtonText);
    if (configured.isNotEmpty) return configured;
    final l10n = AppLocalizations.of(context);
    return _index == total - 1 ? (l10n?.getStarted ?? 'Get Started') : (l10n?.next ?? 'Continue');
  }

  // ─── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final rc = di.sl<RemoteConfigService>().getOnboardingConfig();
    final bg = rc?.background;
    final colors = bg?.colorObjects ?? const <Color>[];
    final baseTextColor = wizHexColor(rc?.textColor) ?? WizColors.ink;

    final content = BlocConsumer<OnboardingBloc, OnboardingState>(
      listener: (context, state) {
        if (state is OnboardingCompleted) context.go(AppRoutes.main);
      },
      builder: (context, state) {
        if (state is OnboardingConfigLoaded) {
          if (state.screens.isEmpty) return _Message(text: AppLocalizations.of(context)?.noOnboardingConfig ?? 'No onboarding configured.');
          return _buildFlow(context, state, baseTextColor);
        }
        if (state is OnboardingError) {
          return _Message(
            text: state.message,
            action: WizSecondaryButton(
              label: AppLocalizations.of(context)?.goBack ?? 'Go back',
              expand: false,
              onPressed: () => context.go(AppRoutes.home),
            ),
          );
        }
        return const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator(color: WizColors.ink)),
        );
      },
    );

    return ConfigurableGradientBackground(
      colors: colors.isEmpty ? WizColors.appGradientColors : colors,
      stops: colors.isEmpty ? WizColors.appGradientStops : (bg!.stops.length == colors.length ? bg.stops : null),
      angleDeg: bg?.angleDeg ?? WizColors.appGradientAngleDeg,
      child: content,
    );
  }

  Widget _buildFlow(BuildContext context, OnboardingConfigLoaded state, Color baseTextColor) {
    final screens = state.screens;
    final index = _index.clamp(0, screens.length - 1);
    final screen = screens[index];
    final textColor = wizHexColor(screen.metadata?.textColor) ?? baseTextColor;
    final valid = _isValid(screen, state.answers[index]);
    final submitting = state is OnboardingSubmitting;

    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && index > 0) _back(state);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(WizSpacing.gutter, 0, WizSpacing.gutter, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: screen.showTopBar ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !screen.showTopBar,
                      child: _TopBar(
                        index: index,
                        total: screens.length,
                        onBack: submitting ? null : () => _back(state),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: screens.length,
                      itemBuilder: (context, i) => _buildScreen(context, screens[i], i, state, textColor),
                    ),
                  ),
                  if (_showsCta(screen))
                    Padding(
                      padding: const EdgeInsets.only(top: WizSpacing.stackLg),
                      child: WizPrimaryButton(
                        label: _ctaText(context, screen, screens.length),
                        loading: submitting,
                        onPressed: valid && !submitting ? () => _next(state) : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScreen(
    BuildContext context,
    OnboardingModel screen,
    int index,
    OnboardingConfigLoaded state,
    Color textColor,
  ) {
    final answer = state.answers[index];
    return screen.when<Widget>(
      multiSelect: (m) => MultiSelectScreenWidget(
        model: m,
        textColor: textColor,
        selectedValues: answer is List ? answer.map((e) => e.toString()).toList() : const [],
        onChanged: (v) => _answer(index, v),
      ),
      select: (m) => SelectScreenWidget(
        model: m,
        textColor: textColor,
        selectedValue: answer?.toString(),
        onOptionSelected: (v) {
          setState(() => _tapped.add(index));
          _answer(index, v);
        },
      ),
      selectGroup: (m) => SelectGroupScreenWidget(
        model: m,
        textColor: textColor,
        values: answer is Map ? Map<String, dynamic>.from(answer) : const {},
        onChanged: (v) => _answer(index, v),
      ),
      slider: (m) => SliderScreenWidget(
        model: m,
        textColor: textColor,
        selectedValue: answer is num ? answer : null,
        onValueChanged: (v) => _answer(index, v),
      ),
      sliderLottie: (m) => SliderLottieScreenWidget(
        model: m,
        textColor: textColor,
        selectedValue: answer is num ? answer : null,
        onValueChanged: (v) => _answer(index, v),
      ),
      referralCode: (m) => ReferralCodeScreenWidget(
        model: m,
        textColor: textColor,
        selectedValue: answer?.toString(),
        onValueChanged: (v) => _answer(index, v),
      ),
      warmup: (m) => WarmupScreenWidget(model: m, textColor: textColor, answersByKey: state.answersByKey),
      createAccount: (m) => CreateAccountScreenWidget(
        model: m,
        textColor: textColor,
        onContinue: () => _goTo(state, index + 1, forward: true),
      ),
      permission: (m) => PermissionScreenWidget(
        model: m,
        textColor: textColor,
        onContinue: () => _goTo(state, index + 1, forward: true),
      ),
      imageList: (m) => ImageListScreenWidget(model: m, textColor: textColor),
      engagement: (m) => EngagementScreenWidget(model: m, textColor: textColor),
      paywall: (m) => PaywallScreenWidget(
        model: m,
        onClose: () => _goTo(state, index + 1, forward: true),
      ),
      dataUpload: (m) => _buildDataUpload(context, m, index, state, textColor),
    );
  }

  Widget _buildDataUpload(
    BuildContext context,
    DataUploadScreenModel model,
    int index,
    OnboardingConfigLoaded state,
    Color textColor,
  ) {
    final config = model.toUploadProgressConfig();
    if (config == null) {
      return const _Message(text: 'Upload screen not configured (missing visual in onboarding_screens).');
    }
    final isActive = index == _index;
    if (isActive && _uploadForIndex != index) {
      _uploadForIndex = index;
      _uploadFuture = di
          .sl<OnboardingRepository>()
          .uploadUserData(OnboardingBloc.buildEntity(state))
          .then((r) => r.fold((f) => throw Exception(f.message), (_) => null));
    }
    final catalog = di.sl.isRegistered<UserProfileService>()
        ? di.sl<UserProfileService>().catalog
        : null;
    final snapshot = OnboardingProfileSnapshot(
      answers: state.answersByKey,
      catalog: catalog ?? OnboardingProfileSnapshot(answers: const {}).catalog,
      languageCode: Localizations.localeOf(context).languageCode,
    );
    return DataUploadScreenWidget(
      key: ValueKey('upload_$index'),
      config: config,
      uploadFuture: _uploadFuture ?? Future<void>.value(),
      isActivePage: isActive,
      placeholders: snapshot.chipPlaceholders,
      textColor: textColor,
      onComplete: () => _bloc.add(const SubmitOnboardingRequested()),
    );
  }
}

/// 44h top bar: back chevron · 4px progress track (ink fill, 350 ms) · "3/9" counter.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.index, required this.total, this.onBack});

  final int index;
  final int total;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 44,
        child: Row(
          children: [
            WizBackChevron(onPressed: onBack),
            const SizedBox(width: 14),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: WizColors.inkTrack,
                  borderRadius: BorderRadius.circular(2),
                ),
                alignment: Alignment.centerLeft,
                child: AnimatedFractionallySizedBox(
                  duration: WizMotion.progress,
                  curve: Curves.easeInOut,
                  alignment: Alignment.centerLeft,
                  widthFactor: total == 0 ? 0 : ((index + 1) / total).clamp(0.0, 1.0),
                  heightFactor: 1,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: WizColors.ink,
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 38),
              child: Text('${index + 1}/$total', textAlign: TextAlign.right, style: WizType.stepCounter),
            ),
          ],
        ),
      );
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(text, textAlign: TextAlign.center, style: WizType.bodyMdInk),
                  if (action != null) ...[const SizedBox(height: 16), action!],
                ],
              ),
            ),
          ),
        ),
      );
}
