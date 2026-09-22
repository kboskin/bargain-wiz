import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:appwizard/core/config/prefs_keys.dart';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/routing/app_routes.dart';
import 'package:appwizard/core/services/feature_gate_service.dart';
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/core/widgets/wiz/fade_up.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/core/widgets/wiz/wiz_chip.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/conversation/domain/conversation_changes.dart';
import 'package:appwizard/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:appwizard/features/express_dealmaker/presentation/pages/express_dealmaker_page.dart';
import 'package:appwizard/features/home/data/models/main_page_config.dart';
import 'package:appwizard/features/home/presentation/utils/home_cta_tags.dart';
import 'package:appwizard/features/home/presentation/utils/share_helper.dart';
import 'package:appwizard/features/home/presentation/widgets/highlighted_text.dart';
import 'package:appwizard/features/home/presentation/widgets/history_grid.dart';
import 'package:appwizard/features/home/presentation/widgets/home_app_bar.dart';
import 'package:appwizard/features/home/presentation/widgets/offline_banner.dart';
import 'package:appwizard/features/main_shell/domain/main_tab.dart';
import 'package:appwizard/features/main_shell/presentation/main_shell_controller.dart';
import 'package:appwizard/features/main_shell/presentation/widgets/wiz_tab_bar.dart';
import 'package:appwizard/features/paywall/presentation/paywall_launcher.dart';
import 'package:appwizard/features/pro_deal_closer/presentation/pages/pro_deal_closer_page.dart';
import 'package:appwizard/features/subscription/domain/entities/subscription_tier.dart';
import 'package:appwizard/l10n/app_localizations.dart';

/// Home tab (README §3): offline banner, app bar, empty state / history grid,
/// first-run nudge and the Express / Pro CTA stack. Rendered inside [MainShellPage].
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  static const String defaultVisual = 'assets/lottie/wizard_hello.json';

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late final ConversationRepository _repo = di.sl<ConversationRepository>();
  /// Fires on every conversation snapshot, so a deal created seconds ago shows up here
  /// without waiting for the next tab switch.
  final ConversationChanges _conversationChanges = ConversationChanges.instance;
  late final FeatureGateService _gate = di.sl<FeatureGateService>();
  late final SharedPreferences _prefs = di.sl<SharedPreferences>();
  MainShellController? _shell;

  List<Conversation> _history = const [];
  bool _loaded = false;
  bool _navigating = false;
  SubscriptionTier? _tier;
  bool _expressUsed = false;
  bool _nudgePending = false;

  @override
  void initState() {
    super.initState();
    _gate.addListener(_refreshTier);
    _conversationChanges.addListener(_onConversationsChanged);
    _refreshTier();
    _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shell = MainShellScope.maybeOf(context, listen: false);
    if (shell != _shell) {
      _shell?.removeListener(_onShellChanged);
      _shell = shell;
      _shell?.addListener(_onShellChanged);
    }
  }

  @override
  void dispose() {
    _gate.removeListener(_refreshTier);
    _conversationChanges.removeListener(_onConversationsChanged);
    _shell?.removeListener(_onShellChanged);
    super.dispose();
  }

  void _onConversationsChanged() {
    if (mounted) unawaited(_reload());
  }

  void _onShellChanged() {
    if (_shell?.tab == MainTab.home) _reload();
  }

  Future<void> _refreshTier() async {
    final tier = await _gate.currentTier();
    if (mounted && tier != _tier) setState(() => _tier = tier);
  }

  Future<void> _reload() async {
    final result = await _repo.getConversations();
    if (!mounted) return;
    final list = result.fold((_) => _history, (l) => List<Conversation>.of(l))
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    setState(() {
      _history = list;
      _loaded = true;
      _expressUsed = _prefs.getBool(PrefsKeys.expressUsed) ?? false;
      _nudgePending = _prefs.getBool(PrefsKeys.firstRunNudgePending) ?? false;
    });
  }

  Future<void> _delete(Conversation c) async {
    setState(() => _history = _history.where((e) => e.id != c.id).toList());
    await _repo.deleteConversation(c.id);
    if (mounted) _reload();
  }

  Future<void> _open(Conversation c) async {
    if (_navigating) return;
    _navigating = true;
    try {
      if (c.type == ConversationType.express) {
        await context.push(AppRoutes.express, extra: ExpressDealmakerArgs(conversationId: c.id));
      } else {
        await context.push(AppRoutes.pro, extra: ProDealCloserArgs(conversationId: c.id));
      }
    } finally {
      _navigating = false;
    }
    if (mounted) _reload();
  }

  Future<void> _start(GatedFeature feature, String route) async {
    if (_navigating) return;
    _navigating = true;
    try {
      final allowed = await FeatureAccess.ensure(context, feature);
      if (!allowed || !mounted) return;
      await context.push(route);
    } finally {
      _navigating = false;
    }
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cfg = di.sl<RemoteConfigService>().getMainPageConfig();
    final tags = HomeCtaTags.forTier(_tier);
    final showNudge = _loaded &&
        showFirstRunNudge(expressUsed: _expressUsed, nudgePending: _nudgePending, historyEmpty: _history.isEmpty);
    final bottomPad = WizTabBar.contentPaddingFor(context);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OfflineBanner(
            text: TemplateText.textOf(
              context,
              cfg?.offlineBanner,
              fallback: "You're offline. Saved deals still work; new lines need a connection.",
            ),
          ),
          HomeAppBar(
            title: l10n.appTitle,
            shareLabel: l10n.share,
            onMenu: () {
              if (_shell != null) {
                _shell!.openDrawer();
              } else {
                Scaffold.maybeOf(context)?.openDrawer();
              }
            },
            onShare: () => ShareHelper.shareApp(context),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: WizSpacing.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_loaded)
                    const Spacer()
                  else if (_history.isEmpty)
                    Expanded(child: _EmptyState(cfg: cfg))
                  else
                    Expanded(child: _historySection(context, cfg, l10n)),
                  Padding(
                    padding: EdgeInsets.only(bottom: bottomPad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showNudge) ...[
                          Bob(
                            child: Text(
                              TemplateText.textOf(
                                context,
                                cfg?.firstRunNudge,
                                fallback: 'Start here — drop a listing or chat screenshot 👇',
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: WizType.captionStrong.copyWith(color: WizColors.purple),
                            ),
                          ),
                          const SizedBox(height: WizSpacing.stack),
                        ],
                        WizPrimaryButton(
                          height: 58,
                          label: TemplateText.textOf(context, cfg?.primaryCtaButton, fallback: 'Express Dealmaker'),
                          leading: const Icon(Icons.photo_camera_outlined, size: 20, color: Colors.white),
                          trailing: tags.showExpressLockTag ? const WizTag(label: '🔒') : null,
                          onPressed: () => _start(GatedFeature.expressDealmaker, AppRoutes.express),
                        ),
                        const SizedBox(height: WizSpacing.stack),
                        WizSecondaryButton(
                          label: TemplateText.textOf(context, cfg?.additionCtaButton, fallback: 'Pro Deal Closer'),
                          leading: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: WizColors.ink),
                          trailing: tags.showProLockTag ? const WizTag(label: '🔒') : null,
                          onPressed: () => _start(GatedFeature.proDealCloser, AppRoutes.pro),
                        ),
                      ],
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

  Widget _historySection(BuildContext context, MainPageConfig? cfg, AppLocalizations l10n) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    TemplateText.textOf(context, cfg?.historySectionTitle, fallback: 'Your bargains'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: WizType.sectionTitle,
                  ),
                ),
                WizTextLink(
                  label: TemplateText.textOf(context, cfg?.historySeeAll, fallback: 'See all'),
                  onPressed: () => _shell?.select(MainTab.history),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 12),
              child: HistoryGrid(
                conversations: _history,
                onOpen: _open,
                onDelete: _delete,
              ),
            ),
          ),
        ],
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.cfg});

  final MainPageConfig? cfg;

  @override
  Widget build(BuildContext context) {
    final visual = cfg?.centerVisual;
    final path = (visual?.visual ?? '').isNotEmpty ? visual!.visual : HomeTab.defaultVisual;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        HighlightedText(
          TemplateText.textOf(context, cfg?.emptyHeadline, fallback: 'Your deal, upgraded.'),
          textAlign: TextAlign.center,
          style: WizType.titleXl,
          highlights: cfg?.emptyHeadlineHighlight,
          defaultHighlightColor: WizColors.purple,
        ),
        const SizedBox(height: 8),
        Text(
          TemplateText.textOf(context, cfg?.headerText, fallback: 'Add a product or negotiation screenshot'),
          textAlign: TextAlign.center,
          style: WizType.bodyMd,
        ),
        Expanded(
          child: Center(
            // Scale down on short screens instead of overflowing the flexible area.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: VisualAssetWidget(
                visualPath: path,
                width: visual?.width ?? 220,
                height: visual?.height ?? 220,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
