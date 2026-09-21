import 'dart:async';
import 'dart:math' as math;

import 'package:appwizard/core/config/feature_gate_policy.dart';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/routing/app_routes.dart';
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/services/user_profile_service.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/gallery_picker_helper.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/wiz/wiz_header.dart';
import 'package:appwizard/core/widgets/wiz/wiz_toast.dart';
import 'package:appwizard/features/home/data/models/main_page_config.dart';
import 'package:appwizard/features/paywall/presentation/paywall_launcher.dart';
import 'package:appwizard/features/profile/domain/profile_fields.dart';
import 'package:appwizard/features/pro_deal_closer/presentation/cubit/pro_deal_closer_cubit.dart';
import 'package:appwizard/features/pro_deal_closer/presentation/cubit/pro_deal_closer_state.dart';
import 'package:appwizard/features/pro_deal_closer/presentation/widgets/pro_composer.dart';
import 'package:appwizard/features/pro_deal_closer/presentation/widgets/pro_message_tile.dart';
import 'package:appwizard/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Route `extra` for [AppRoutes.pro].
class ProDealCloserArgs {
  const ProDealCloserArgs({this.conversationId});

  /// Reopen a saved Pro Deal Closer conversation (from history).
  final String? conversationId;
}

/// Pro Deal Closer chat with the wizard (full-screen route `/pro`).
/// Gated by [GatedFeature.proDealCloser]; saves to history on back.
class ProDealCloserPage extends StatelessWidget {
  const ProDealCloserPage({super.key, this.args});

  final ProDealCloserArgs? args;

  @override
  Widget build(BuildContext context) => BlocProvider<ProDealCloserCubit>(
        create: (_) => di.sl<ProDealCloserCubit>(),
        child: _ProDealCloserView(conversationId: args?.conversationId),
      );
}

class _ProDealCloserView extends StatefulWidget {
  const _ProDealCloserView({this.conversationId});

  final String? conversationId;

  @override
  State<_ProDealCloserView> createState() => _ProDealCloserViewState();
}

class _ProDealCloserViewState extends State<_ProDealCloserView> {
  final ScrollController _scroll = ScrollController();
  final List<Timer> _scrollTimers = [];
  late final UserProfileService _profile = di.sl<UserProfileService>();
  late final RemoteConfigService _remoteConfig = di.sl<RemoteConfigService>();
  late final MainPageConfig? _config = _remoteConfig.getMainPageConfig();
  bool _leaving = false;

  /// The answers this deal carries its own value for — whatever the template marks
  /// `scope: "conversation"`, in onboarding order. Empty when no screen offers one.
  List<ProfileField> get _scoped => ProfileFields.conversationScoped(_profile.fields);

  /// What a new deal starts from: the stored answer for each of those, else the screen's
  /// configured default. A reopened deal ignores this and keeps what it was saved with.
  /// Nothing in the chat changes them — the Profile screen owns every value.
  Map<String, dynamic> get _defaults => {
        for (final field in _scoped)
          if ((_profile.valueOf(field.key) ?? field.defaultValue) case final value?) field.key: value,
      };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_bootstrap()));
  }

  @override
  void dispose() {
    for (final t in _scrollTimers) {
      t.cancel();
    }
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final locale = Localizations.localeOf(context).languageCode;
    final cubit = context.read<ProDealCloserCubit>();
    // Gate first (may push the paywall on top); the chat loads underneath meanwhile.
    final gate = FeatureAccess.ensure(context, GatedFeature.proDealCloser);
    await _profile.ensureLoaded();
    if (!mounted) return;
    await cubit.start(
      conversationId: widget.conversationId,
      overrides: _defaults,
      locale: locale,
    );
    final allowed = await gate;
    if (!allowed && mounted) _pop();
  }

  /// Back (chevron / system): persist when the user wrote something, then leave.
  Future<void> _onBack() async {
    if (_leaving) return;
    _leaving = true;
    await context.read<ProDealCloserCubit>().save();
    if (mounted) _pop();
  }

  void _pop() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.main);
    }
  }

  Future<void> _attach() async {
    final cubit = context.read<ProDealCloserCubit>();
    final picked = await GalleryPickerHelper.pickImages(context);
    if (!mounted || picked.isEmpty) return;
    await cubit.sendAttachments(picked.map((x) => x.path).toList());
  }

  /// Scroll to the bottom now and again shortly after, so late layout
  /// (images, entrance animations) is covered — mirrors the prototype.
  void _scrollToBottom() {
    void jump() {
      if (!mounted || !_scroll.hasClients) return;
      unawaited(_scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: WizMotion.easeOut,
      ));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => jump());
    _scrollTimers
      ..removeWhere((t) => !t.isActive)
      ..add(Timer(const Duration(milliseconds: 150), jump))
      ..add(Timer(const Duration(milliseconds: 400), jump));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = TemplateText.textOf(
      context,
      _config?.additionCtaButton,
      fallback: l10n?.chatModeTitle ?? 'Pro Deal Closer',
    );
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final composerBottom = keyboardOpen ? 14.0 : math.max(WizSpacing.homeIndicator, safeBottom);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_onBack());
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: MultiBlocListener(
          listeners: [
            BlocListener<ProDealCloserCubit, ProDealCloserState>(
              listenWhen: (prev, curr) =>
                  prev.messages != curr.messages || prev.isTyping != curr.isTyping,
              listener: (_, __) => _scrollToBottom(),
            ),
            BlocListener<ProDealCloserCubit, ProDealCloserState>(
              listenWhen: (prev, curr) => prev.errorCount != curr.errorCount,
              listener: (context, _) => WizToast.show(
                context,
                TemplateText.textOf(context, _config?.expressErrorTitle, fallback: 'The spell fizzled'),
              ),
            ),
          ],
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                WizHeader(
                  title: title,
                  onBack: _onBack,
                  horizontalPadding: 16,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _MessageList(controller: _scroll, config: _config),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: ProComposer(
                          onSend: (text) => unawaited(context.read<ProDealCloserCubit>().sendText(text)),
                          onAttach: () => unawaited(_attach()),
                          showMic: _config?.showMic ?? true,
                          bottomPadding: composerBottom,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Messages (padding 8 16 0, gap 10) + typing indicator + 120 px spacer for the composer.
class _MessageList extends StatelessWidget {
  const _MessageList({required this.controller, this.config});

  final ScrollController controller;
  final MainPageConfig? config;

  @override
  Widget build(BuildContext context) {
    final readingLabel = TemplateText.textOf(context, config?.proReadingLabel, fallback: 'Reading…');
    final optionsLabel = TemplateText.textOf(context, config?.proOptionsCta, fallback: '✨ Give me options');
    final redoLabel = TemplateText.textOf(context, config?.proRedoCta, fallback: '↻ Redo');

    return BlocBuilder<ProDealCloserCubit, ProDealCloserState>(
      builder: (context, state) {
        final cubit = context.read<ProDealCloserCubit>();
        final typingIndex = state.isTyping ? state.messages.length : -1;
        final count = state.messages.length + (state.isTyping ? 1 : 0) + 1;
        return ListView.builder(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          itemCount: count,
          itemBuilder: (context, index) {
            if (index == count - 1) return const SizedBox(height: 120);
            if (index == typingIndex) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: TypingBubble(),
              );
            }
            final message = state.messages[index];
            return Padding(
              key: ValueKey(message.id),
              padding: const EdgeInsets.only(bottom: 10),
              child: ProMessageTile(
                message: message,
                readingLabel: readingLabel,
                optionsLabel: optionsLabel,
                redoLabel: redoLabel,
                copiedToast: 'Copied to clipboard',
                onOptions: () => unawaited(cubit.requestOptions(message.id)),
                onRedo: () => unawaited(cubit.redo(message.id)),
              ),
            );
          },
        );
      },
    );
  }
}
