import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/theme/option_style.dart';
import 'package:appwizard/core/routing/app_routes.dart';
import 'package:appwizard/core/services/feature_gate_service.dart';
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/services/user_profile_service.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/gallery_picker_helper.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/wiz/wiz_chip.dart';
import 'package:appwizard/core/widgets/wiz/wiz_header.dart';
import 'package:appwizard/features/express_dealmaker/presentation/cubit/express_dealmaker_cubit.dart';
import 'package:appwizard/features/express_dealmaker/presentation/express_copy.dart';
import 'package:appwizard/features/express_dealmaker/presentation/widgets/express_error_stage.dart';
import 'package:appwizard/features/express_dealmaker/presentation/widgets/express_pick_stage.dart';
import 'package:appwizard/features/express_dealmaker/presentation/widgets/express_results_stage.dart';
import 'package:appwizard/features/express_dealmaker/presentation/widgets/express_uploading_stage.dart';
import 'package:appwizard/features/paywall/presentation/paywall_launcher.dart';
import 'package:appwizard/features/profile/domain/profile_fields.dart';

/// Route `extra` for [AppRoutes.express].
/// What a new deal starts from: the stored answer for each conversation-scoped question,
/// else the screen's configured default. A reopened deal ignores this and keeps its own,
/// so a thread stays in the voice it was written in.
Map<String, dynamic> _defaults(final UserProfileService profile) => {
      for (final field in ProfileFields.conversationScoped(profile.fields))
        if ((profile.valueOf(field.key) ?? field.defaultValue) case final value?) field.key: value,
    };


class ExpressDealmakerArgs {
  const ExpressDealmakerArgs({this.conversationId, this.initialPaths = const []});

  /// Reopen a saved Express conversation (from history).
  final String? conversationId;
  /// Screenshots already picked (skips the pick stage when non-empty).
  final List<String> initialPaths;
}

/// Express Dealmaker (`/express`): pick → uploading → results / error.
/// Transparent scaffold over the app-wide gradient background.
class ExpressDealmakerPage extends StatelessWidget {
  const ExpressDealmakerPage({super.key, this.args});

  final ExpressDealmakerArgs? args;

  @override
  Widget build(final BuildContext context) {
    // Resolve inherited data here, not inside the lazy `create` callback
    // (provider forbids listening to inherited widgets from `create`).
    final languageCode = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
    return BlocProvider<ExpressDealmakerCubit>(
      create: (_) {
        final profile = di.sl<UserProfileService>();
        return di.sl<ExpressDealmakerCubit>(
          param1: ExpressDealmakerCubitParams(
            overrides: _defaults(profile),
            locale: languageCode,
          ),
        );
      },
      child: _ExpressDealmakerView(args: args),
    );
  }
}

class _ExpressDealmakerView extends StatefulWidget {
  const _ExpressDealmakerView({this.args});

  final ExpressDealmakerArgs? args;

  @override
  State<_ExpressDealmakerView> createState() => _ExpressDealmakerViewState();
}

class _ExpressDealmakerViewState extends State<_ExpressDealmakerView> {
  bool _leaving = false;

  ExpressDealmakerCubit get _cubit => context.read<ExpressDealmakerCubit>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  /// Gate (paywall) → load profile → start the flow (opens the picker when
  /// nothing was passed in).
  Future<void> _init() async {
    if (!mounted) return;
    final allowed = await FeatureAccess.ensure(context, GatedFeature.expressDealmaker);
    if (!mounted) return;
    if (!allowed) {
      _leaving = true;
      _popToHome();
      return;
    }
    final profile = di.sl<UserProfileService>();
    await profile.ensureLoaded();
    if (!mounted) return;

    final args = widget.args;
    final conversationId = args?.conversationId;
    final initialPaths = args?.initialPaths ?? const <String>[];
    // A new deal starts from the profile defaults; a reopened one keeps what it was saved
    // with, so the thread stays in the voice it was written in.
    if (conversationId == null) {
      for (final entry in _defaults(profile).entries) {
        await _cubit.setOverride(entry.key, entry.value);
      }
    }
    if (conversationId == null && initialPaths.isEmpty) {
      unawaited(_cubit.start());
      await _pickScreenshots();
      return;
    }
    unawaited(_cubit.start(conversationId: conversationId, initialPaths: initialPaths));
  }

  Future<void> _pickScreenshots() async {
    final picked = await GalleryPickerHelper.pickImages(context);
    if (!mounted || picked.isEmpty) return;
    _cubit.addPaths(picked.map((final x) => x.path).toList());
  }

  /// Changing a chip changes **this deal only**. The profile default is deliberately left
  /// alone — the Profile screen is where that is edited (CONVERSATIONS.md).
  Future<void> _setOverride(final String key, final dynamic value) => _cubit.setOverride(key, value);

  /// Back (chevron / system): save to history, then pop.
  Future<void> _onBack() async {
    if (_leaving) return;
    _leaving = true;
    await _cubit.saveConversation();
    if (!mounted) return;
    _popToHome();
  }

  void _popToHome() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.main);
    }
  }

  @override
  Widget build(final BuildContext context) {
    final config = di.sl<RemoteConfigService>().getMainPageConfig();
    final copy = ExpressCopy.resolve(context, config);
    // The answers this deal may override, as onboarding offers them (labels, colours, glyphs).
    final scoped = ProfileFields.conversationScoped(di.sl<UserProfileService>().fields);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (final didPop, final _) {
        if (!didPop) unawaited(_onBack());
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: BlocBuilder<ExpressDealmakerCubit, ExpressDealmakerState>(
            builder: (final context, final state) {
              // The header tag shows the first overridable answer — the tone, as configured.
              final primary = scoped.firstOrNull;
              final tone = primary == null ? null : primary.optionFor(state.overrides[primary.key]);
              final toneStyle = OptionStyle.of(tone);
              return Column(
                children: [
                  WizHeader(
                    title: copy.headerTitle,
                    horizontalPadding: 16,
                    onBack: _onBack,
                    trailing: tone == null
                        ? null
                        : WizTag(
                            label: TemplateText.textOf(context, tone.shortLabel ?? tone.label),
                            color: toneStyle.textColor,
                            textColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            style: WizType.chip,
                          ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      layoutBuilder: (final current, final previous) => Stack(
                        fit: StackFit.expand,
                        children: [...previous, if (current != null) current],
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(state.loadingConversation ? 'loading' : state.phase),
                        child: _buildStage(state, copy, scoped),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStage(
    final ExpressDealmakerState state,
    final ExpressCopy copy,
    final List<ProfileField> scoped,
  ) {
    if (state.loadingConversation) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: WizColors.purple),
        ),
      );
    }
    switch (state.phase) {
      case ExpressPhase.pick:
        return ExpressPickStage(
          items: state.screenshots,
          copy: copy,
          onPick: _pickScreenshots,
          onRemove: _cubit.removeAt,
          onStart: () => unawaited(_cubit.startUpload()),
        );
      case ExpressPhase.uploading:
        return ExpressUploadingStage(
          items: state.screenshots,
          copy: copy,
          onRetry: (final i) => unawaited(_cubit.retryUpload(i)),
        );
      case ExpressPhase.error:
        return ExpressErrorStage(
          copy: copy,
          message: state.errorMessage,
          onRetry: () => unawaited(_cubit.retry()),
        );
      case ExpressPhase.ready:
        return ExpressResultsStage(
          state: state,
          copy: copy,
          scoped: scoped,
          onPick: _pickScreenshots,
          onRetryUpload: (final i) => unawaited(_cubit.retryUpload(i)),
          onKeywordChanged: _cubit.setKeyword,
          onOverride: (final key, final value) => unawaited(_setOverride(key, value)),
          onGetMore: () => unawaited(_cubit.requestReply()),
        );
    }
  }
}
