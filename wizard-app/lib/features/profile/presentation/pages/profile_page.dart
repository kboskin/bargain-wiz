import 'package:dartz/dartz.dart' show Right;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/services/feature_gate_service.dart';
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/services/user_profile_service.dart';
import 'package:appwizard/core/theme/option_style.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/wiz/fade_up.dart';
import 'package:appwizard/core/widgets/wiz/wiz_toast.dart';
import 'package:appwizard/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:appwizard/features/auth/presentation/bloc/auth_event.dart';
import 'package:appwizard/features/auth/presentation/pages/sign_in_modal.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_model.dart';
import 'package:appwizard/features/paywall/data/models/paywall_config.dart';
import 'package:appwizard/features/paywall/domain/paywall_copy.dart';
import 'package:appwizard/features/paywall/presentation/paywall_launcher.dart';
import 'package:appwizard/features/profile/domain/profile_fields.dart';
import 'package:appwizard/features/profile/domain/profile_plan_copy.dart';
import 'package:appwizard/features/profile/presentation/widgets/profile_account_card.dart';
import 'package:appwizard/features/profile/presentation/widgets/profile_answer_sheets.dart';
import 'package:appwizard/features/profile/presentation/widgets/profile_developer_card.dart';
import 'package:appwizard/features/profile/presentation/widgets/profile_plan_card.dart';
import 'package:appwizard/features/profile/presentation/widgets/profile_meter_card.dart';
import 'package:appwizard/features/profile/presentation/widgets/profile_settings_card.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_screen_config.dart';
import 'package:appwizard/features/profile/presentation/widgets/profile_chip_card.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_product.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_status.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';
import 'package:appwizard/features/subscription/domain/repositories/subscription_repository.dart';

/// Profile tab body (design handoff §8): account · plan · negotiation vibe · push level ·
/// every other onboarding answer · settings (· developer tier override). Rendered inside the
/// main shell as a tab body, so it is a plain scrollable that leaves
/// [WizSpacing.tabBarContentPadding] at the bottom.
///
/// The answer rows are built from the `onboarding_screens` templates ([ProfileFields]), so the
/// screen offers exactly what onboarding asked — a screen added remotely shows up here too.
/// Vibe and push keep their own cards and are left out of the rows, and so are the answers
/// onboarding locks ([ProfileFields.lockedKeys]): a referral code is entered once.
/// How the Profile screen draws one answer.
enum _Card { chips, meter, row }

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final UserProfileService _profile = di.sl<UserProfileService>();
  final FeatureGateService _gate = di.sl<FeatureGateService>();
  final RemoteConfigService _remoteConfig = di.sl<RemoteConfigService>();
  final SubscriptionRepository _subscriptions = di.sl<SubscriptionRepository>();
  final AppLogger _logger = di.sl<AppLogger>();

  PaywallConfig? _paywall;
  SubscriptionTier _tier = SubscriptionTier.free;
  SubscriptionStatus? _status;
  List<SubscriptionProduct>? _products;
  int _planRequest = 0;

  @override
  void initState() {
    super.initState();
    try {
      _paywall = _remoteConfig.getPaywallConfig();
    } catch (e, st) {
      _logger.e('ProfilePage: paywall config unavailable', e, st);
    }
    _profile.ensureLoaded();
    _gate.addListener(_reloadPlan);
    _reloadPlan();
  }

  @override
  void dispose() {
    _gate.removeListener(_reloadPlan);
    super.dispose();
  }

  // ── plan ─────────────────────────────────────────────────────────────────

  Future<void> _reloadPlan() async {
    final request = ++_planRequest;
    try {
      final tier = await _gate.currentTier();
      if (!mounted || request != _planRequest) return;
      // Show the effective tier right away; status / store prices are best-effort
      // and may be slow or unavailable (no billing on emulators, signed-out users).
      setState(() => _tier = tier);
      SubscriptionStatus? status;
      if (tier != SubscriptionTier.free) {
        final statusResult = await _subscriptions
            .getSubscriptionStatus()
            .timeout(const Duration(seconds: 8), onTimeout: () => const Right(null));
        status = statusResult.fold((_) => null, (s) => s);
        if (_products == null) {
          final productsResult = await _subscriptions
              .getAvailableProducts()
              .timeout(const Duration(seconds: 8), onTimeout: () => const Right(<SubscriptionProduct>[]));
          _products = productsResult.fold((_) => const <SubscriptionProduct>[], (p) => p);
        }
      }
      if (!mounted || request != _planRequest) return;
      setState(() {
        _tier = tier;
        _status = status;
      });
    } catch (e, st) {
      _logger.e('ProfilePage: failed to load plan', e, st);
    }
  }

  PaywallOption? _optionFor(SubscriptionTier tier) =>
      _paywall?.options.where((o) => o.tierEnum == tier).firstOrNull;

  String? _priceFor(SubscriptionTier tier) {
    final option = _optionFor(tier);
    if (option == null) return null;
    return PaywallPricing.priceFor(
      option,
      _products ?? const [],
      resolve: (v) => TemplateText.textOf(context, v),
    );
  }

  /// Which widget an answer gets, from the template its screen used — so a question added
  /// in Remote Config draws itself without naming a control this build might not have.
  /// Anything unrecognised, including a template added later, becomes a settings row.
  static _Card _cardOf(ProfileField field) => switch (field.template) {
        OnboardingScreenType.sliderLottie => _Card.meter,
        OnboardingScreenType.select => _Card.chips,
        _ => _Card.row,
      };

  /// Editable answers in onboarding order: the ones with a card of their own first, then
  /// the settings rows. [ProfileFields.lockedKeys] never appear (the referral code).
  List<ProfileField> _fields(List<OnboardingModel> screens) =>
      ProfileFields.fromScreens(screens, skip: ProfileFields.lockedKeys);

  Future<void> _openPaywall() async {
    await PaywallLauncher.open(context, entry: PaywallEntry.profile);
    if (mounted) await _reloadPlan();
  }

  // ── account ──────────────────────────────────────────────────────────────

  void _signIn() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SignInModal(),
    );
  }

  void _logOut() {
    context.read<AuthBloc>().add(const SignOutRequested());
    WizToast.show(context, 'Signed out');
  }

  // ── settings ─────────────────────────────────────────────────────────────

  /// Opens the sheet that fits the answer: chips, tick rows or a text field.
  void _edit(ProfileField field) {
    final answer = _profile.answer(field.key);
    final title = TemplateText.textOf(context, field.label, fallback: field.key);
    switch (field.kind) {
      case ProfileFieldKind.single:
        showProfileOptionSheet(
          context,
          title: title,
          options: field.options,
          selected: answer?.toString(),
          onPick: (value) => _profile.setAnswer(field.key, ProfileFields.storedValue(field, value)),
          iconFor: OptionStyle.iconOf,
        );
      case ProfileFieldKind.multi:
        showProfileMultiSelectSheet(
          context,
          title: title,
          options: field.options,
          selected: ProfileFields.valuesOf(answer),
          minSelected: field.minSelected,
          onSave: (values) => _profile.setAnswer(field.key, values),
        );
      case ProfileFieldKind.text:
        final hint = TemplateText.textOf(context, field.placeholder);
        showProfileTextSheet(
          context,
          title: title,
          value: answer?.toString(),
          hintText: hint.isEmpty ? null : hint,
          uppercase: field.uppercase,
          onSave: (text) => _profile.setAnswer(field.key, text),
        );
    }
  }

  /// Chip glyph: whatever the option configures, nothing when it configures none.

  static String localeName(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      default:
        return locale.toLanguageTag();
    }
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([_profile, _gate]),
        builder: (context, _) {
          final planOption = _optionFor(_tier);
          final planName = ProfilePlanCopy.planName(
            _tier,
            optionTitle: planOption == null ? null : TemplateText.textOf(context, planOption.title),
          );
          final planSub = ProfilePlanCopy.planSub(
            tier: _tier,
            status: _status,
            price: _priceFor(_tier),
            now: DateTime.now(),
            trialDays: _paywall?.trialDays ?? 3,
            formatDate: (d) => PaywallDates.monthDay(
              d,
              locale: Localizations.maybeLocaleOf(context)?.toLanguageTag(),
            ),
          );
          final locale = Localizations.maybeLocaleOf(context) ?? const Locale('en');
          String resolve(dynamic v) => TemplateText.textOf(context, v);
          final screens = _remoteConfig.getOnboardingScreens();
          final all = _fields(screens);
          final cards = [for (final f in all) if (_cardOf(f) != _Card.row) f];
          final rows = [for (final f in all) if (_cardOf(f) == _Card.row) f];

          return SafeArea(
            bottom: false,
            child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              WizSpacing.gutter,
              12,
              WizSpacing.gutter,
              WizSpacing.tabBarContentPadding,
            ),
            child: StaggeredFadeUpColumn(
              gap: WizSpacing.stackLg,
              children: [
                ProfileAccountCard(onSignIn: _signIn, onLogOut: _logOut),
                ProfilePlanCard(
                  name: planName,
                  subtitle: planSub,
                  ctaLabel: ProfilePlanCopy.cta(_tier),
                  onCta: _openPaywall,
                ),
                for (final field in cards)
                  if (_cardOf(field) == _Card.chips)
                    ProfileChipCard(
                      title: TemplateText.textOf(context, field.label, fallback: field.key),
                      options: field.options,
                      selectedValue: _profile.valueOf(field.key)?.toString(),
                      onSelect: (value) => _profile.setAnswer(field.key, value),
                    )
                  else
                    ProfileMeterCard(
                      title: TemplateText.textOf(context, field.label, fallback: field.key),
                      options: field.options,
                      selectedValue: _profile.valueOf(field.key)?.toString(),
                      onSelect: (value) => _profile.setAnswer(field.key, value),
                    ),
                ProfileSettingsCard(
                  rows: [
                    for (final field in rows)
                      ProfileSettingsRow(
                        label: TemplateText.textOf(context, field.label, fallback: field.key),
                        value: ProfileFields.displayValue(
                          field,
                          _profile.answer(field.key),
                          resolve,
                        ),
                        onTap: () => _edit(field),
                      ),
                    ProfileSettingsRow(
                      label: 'Language',
                      value: '${localeName(locale)} · System',
                    ),
                  ],
                ),
                if (_gate.canOverride)
                  ProfileDeveloperCard(
                    tierOverride: _gate.debugOverride,
                    onChange: _gate.setDebugOverride,
                  ),
              ],
            ),
          ),
          );
        },
      );
}
