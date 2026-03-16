import 'dart:io';
import 'dart:ui';

import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/routing/app_routes.dart';
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/utils/color_helper.dart';
import 'package:appwizard/core/utils/gallery_picker_helper.dart';
import 'package:appwizard/core/utils/text_highlight_helper.dart';
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/theme/app_text_styles.dart';
import 'package:appwizard/core/theme/button_style.dart';
import 'package:appwizard/core/widgets/glass_container.dart';
import 'package:appwizard/core/widgets/styled_description_widget.dart';
import 'package:appwizard/core/widgets/styled_rich_text_description_widget.dart';
import 'package:appwizard/core/widgets/styled_title_widget.dart';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';
import 'package:appwizard/features/shared/data/models/remote_config/button_config.dart';
import 'package:appwizard/features/home/data/models/rate_us_modal_config.dart';
import 'package:appwizard/features/home/presentation/widgets/glass_two_choice_modal.dart';
import 'package:appwizard/features/home/data/models/main_page_config.dart';
import 'package:appwizard/features/home/data/models/refer_config.dart';
import 'package:appwizard/features/home/data/models/share_config.dart';
import 'package:appwizard/l10n/app_localizations.dart';
import 'package:appwizard/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:appwizard/features/auth/presentation/bloc/auth_event.dart';
import 'package:appwizard/features/auth/presentation/bloc/auth_state.dart';
import 'package:appwizard/features/start_with_text/presentation/pages/start_with_text_page.dart';
import 'package:appwizard/features/express_dealmaker/presentation/pages/simple_mode_section.dart';
import 'package:appwizard/features/express_dealmaker/presentation/pages/screenshot_upload_item.dart';
import 'package:appwizard/features/express_dealmaker/domain/repositories/express_dealmaker_repository.dart';
import 'package:appwizard/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart' show Conversation, ConversationType, ProDealCloserMessage;
import 'package:appwizard/features/lines_that_land/presentation/bloc/lines_that_land_bloc.dart';
import 'package:appwizard/features/lines_that_land/presentation/widgets/lines_that_land_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  static const double _kScrolledThreshold = 20;
  bool _isScrolledToChat = false;
  int _conversationKey = 0;
  String? _activeConversationId;
  ConversationType? _activeConversationType;
  List<ScreenshotUploadItem> _expressDealmakerItems = [];
  final List<_ConversationSnapshot> _conversationHistory = [];
  List<String>? _activeInitialReplyOptions;
  String? _activeInitialKeyword;
  List<_ProDealCloserMessageSnapshot>? _proDealCloserInitialMessages;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScrollChanged);
    _loadConversationHistory();
    // Simple overlay trigger
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.push(AppRoutes.paywall);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      context.push(AppRoutes.paywall);
    }
  }

  void _onScrollChanged() {
    final isScrolled = _scrollController.hasClients &&
        _scrollController.offset > _kScrolledThreshold;
    if (isScrolled != _isScrolledToChat) {
      setState(() => _isScrolledToChat = isScrolled);
    }
  }

  void _onShare(BuildContext context) {
    final config = di.sl<RemoteConfigService>().getShareConfig() ??
        ShareConfig.defaultConfig;
    final title = config.getTitle(context).trim();
    final description = config.getDescription(context).trim();
    final linkUrl = config.linkUrl?.trim() ?? '';
    final parts = <String>[];
    if (title.isNotEmpty) parts.add(title);
    if (description.isNotEmpty) parts.add(description);
    if (linkUrl.isNotEmpty) parts.add(linkUrl);
    final text = parts.join('\n\n');
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to share')),
      );
      return;
    }
    Share.share(
      text,
      subject: title.isNotEmpty ? title : null,
    );
  }

  void _scrollTo(double offset) {
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _handleSystemBack() {
    if (_isScrolledToChat) {
      _scrollTo(0);
    }
  }

  void _showReferBenefitsSheet(BuildContext context, AppLocalizations l10n) {
    final referConfig = di.sl<RemoteConfigService>().getReferConfig();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ReferBenefitsSheet(
        l10n: l10n,
        referConfig: referConfig,
        onShareInvite: () {
          Navigator.of(ctx).pop();
          _onShareRefer(ctx, referConfig);
        },
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _onShareRefer(BuildContext context, ReferConfig? referConfig) {
    if (referConfig != null &&
        (referConfig.getShareTitle(context).isNotEmpty ||
            referConfig.getShareDescription(context).isNotEmpty ||
            (referConfig.shareLinkUrl ?? '').isNotEmpty)) {
      final parts = <String>[];
      final title = referConfig.getShareTitle(context).trim();
      final description = referConfig.getShareDescription(context).trim();
      final linkUrl = (referConfig.shareLinkUrl ?? '').trim();
      if (title.isNotEmpty) parts.add(title);
      if (description.isNotEmpty) parts.add(description);
      if (linkUrl.isNotEmpty) parts.add(linkUrl);
      final text = parts.join('\n\n');
      if (text.isNotEmpty) {
        Share.share(text, subject: title.isNotEmpty ? title : null);
        return;
      }
    }
    _onShare(context);
  }

  void _showLinesThatLandTips(BuildContext context) {
    final bloc = di.sl<LinesThatLandBloc>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BlocProvider<LinesThatLandBloc>.value(
        value: bloc,
        child: _LinesThatLandBottomSheet(
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  Future<void> _loadConversationHistory() async {
    final repo = di.sl<ConversationRepository>();
    final result = await repo.getConversations();
    result.fold(
      (_) {},
      (entities) {
        if (!mounted) return;
        setState(() {
          _conversationHistory
            ..clear()
            ..addAll(
              entities.map((e) {
                if (e.type == ConversationType.proDealCloser) {
                  return _ConversationSnapshot(
                    id: e.id,
                    type: e.type.name,
                    screenshots: const [],
                    replyOptions: e.replyOptions,
                    keyword: e.keyword,
                    messages: e.messages
                        .map((m) => _ProDealCloserMessageSnapshot(
                              text: m.text,
                              attachmentPaths: List<String>.from(m.attachmentPaths),
                            ))
                        .toList(),
                    createdAt: e.createdAt,
                  );
                }
                return _ConversationSnapshot(
                  id: e.id,
                  type: e.type.name,
                  screenshots: e.screenshotPaths
                      .map((p) => ScreenshotUploadItem(path: p))
                      .toList(),
                  replyOptions: e.replyOptions,
                  keyword: e.keyword,
                  messages: const [],
                  createdAt: e.createdAt,
                );
              }),
            );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mainPageConfig = di.sl<RemoteConfigService>().getMainPageConfig();

    return PopScope(
      canPop: !_isScrolledToChat,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleSystemBack();
      },
      child: Scaffold(
      backgroundColor: Colors.transparent,
      drawerScrimColor: Colors.black.withValues(alpha: 0.2),
      appBar: AppBar(
        title: Text(
          l10n.appTitle,
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withValues(
                alpha: mainPageConfig?.stripeOpacity ?? 0.12,
              ),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _onShare(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDark,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.share_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.share,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: _HomeDrawer(
        l10n: l10n,
        onReferTap: () => _showReferBenefitsSheet(context, l10n),
        termsUrl: di.sl<RemoteConfigService>().getTermsOfUseUrl(),
        privacyUrl: di.sl<RemoteConfigService>().getPrivacyPolicyUrl(),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewportHeight = constraints.maxHeight;
            return SingleChildScrollView(
              controller: _scrollController,
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                children: [
                  SizedBox(
                    height: viewportHeight,
                    child: _expressDealmakerItems.isNotEmpty
                        ? SimpleModeSection(
                            screenshotItems: _expressDealmakerItems,
                            onBack: () => setState(() {
                              _expressDealmakerItems = [];
                              _activeInitialReplyOptions = null;
                              _activeInitialKeyword = null;
                            }),
                            onAddPaths: (paths) {
                              setState(() {
                                _activeConversationType = ConversationType.express;
                                _activeConversationId ??= null;
                                _expressDealmakerItems = [
                                  ..._expressDealmakerItems,
                                  ...paths.map((p) => ScreenshotUploadItem(path: p)),
                                ];
                              });
                            },
                            onItemStatusChange: (index, status) {
                              if (index < 0 || index >= _expressDealmakerItems.length) return;
                              setState(() {
                                _expressDealmakerItems = [
                                  ..._expressDealmakerItems.sublist(0, index),
                                  _expressDealmakerItems[index].copyWith(status: status),
                                  ..._expressDealmakerItems.sublist(index + 1),
                                ];
                              });
                            },
                            initialReplyOptions: _activeInitialReplyOptions,
                            initialKeyword: _activeInitialKeyword,
                            onCloseConversation: (screenshots, replyOptions, keyword) {
                              final now = DateTime.now();
                              final id = _activeConversationType == ConversationType.express &&
                                      _activeConversationId != null
                                  ? _activeConversationId!
                                  : now.millisecondsSinceEpoch.toString();
                              final paths = screenshots.map((e) => e.path).toList();
                              final entity = Conversation(
                                id: id,
                                type: ConversationType.express,
                                screenshotPaths: paths,
                                replyOptions: replyOptions ?? const [],
                                keyword: keyword,
                                messages: const [],
                                createdAt: now,
                              );
                              final repo = di.sl<ConversationRepository>();
                              repo.saveConversation(entity);
                              setState(() {
                                _activeConversationId = id;
                                _activeConversationType = ConversationType.express;
                                _conversationHistory.removeWhere((c) => c.id == id);
                                _conversationHistory.insert(
                                  0,
                                  _ConversationSnapshot(
                                    id: id,
                                    type: ConversationType.express.name,
                                    screenshots: List<ScreenshotUploadItem>.from(screenshots),
                                    replyOptions: replyOptions ?? const [],
                                    keyword: keyword,
                                    messages: const [],
                                    createdAt: now,
                                  ),
                                );
                              });
                            },
                            expressDealmakerRepository: di.sl<ExpressDealmakerRepository>(),
                          )
                        : _conversationHistory.isNotEmpty
                            ? _ExpressDealmakerHistoryView(
                                l10n: l10n,
                                conversationHistory: _conversationHistory,
                                onConversationSelected: (snapshot) {
                                      if (snapshot.type == ConversationType.proDealCloser.name) {
                                        setState(() {
                                          _activeConversationId = snapshot.id;
                                          _activeConversationType = ConversationType.proDealCloser;
                                          _proDealCloserInitialMessages =
                                              snapshot.messages.isNotEmpty
                                                  ? List<_ProDealCloserMessageSnapshot>.from(
                                                      snapshot.messages,
                                                    )
                                                  : null;
                                          _conversationKey++;
                                        });
                                        _scrollTo(viewportHeight);
                                      } else {
                                        setState(() {
                                          _activeConversationId = snapshot.id;
                                          _activeConversationType = ConversationType.express;
                                          _expressDealmakerItems =
                                              List<ScreenshotUploadItem>.from(
                                            snapshot.screenshots,
                                          );
                                          _activeInitialReplyOptions =
                                              snapshot.replyOptions;
                                          _activeInitialKeyword = snapshot.keyword;
                                        });
                                      }
                                },
                                onDelete: (snapshot) {
                                  setState(() {
                                    _conversationHistory.remove(snapshot);
                                  });
                                  final repo = di.sl<ConversationRepository>();
                                  repo.deleteConversation(snapshot.id);
                                },
                                onStartWithText: () {
                                  setState(() {
                                    _activeConversationId = null;
                                    _activeConversationType = ConversationType.proDealCloser;
                                    _conversationKey++;
                                    _proDealCloserInitialMessages = null;
                                  });
                                  _scrollTo(viewportHeight);
                                },
                                onGetPickupLines: () => _showLinesThatLandTips(context),
                                onExpressDealmakerPicked: (paths) {
                                  setState(() {
                                    _expressDealmakerItems = paths
                                        .map(
                                          (p) =>
                                              ScreenshotUploadItem(path: p),
                                        )
                                        .toList();
                                    _activeConversationId = null;
                                    _activeConversationType = ConversationType.express;
                                    _activeInitialReplyOptions = null;
                                    _activeInitialKeyword = null;
                                  });
                                },
                              )
                            : _EmptyStateContent(
                                l10n: l10n,
                                config: mainPageConfig,
                                onStartWithText: () {
                                  setState(() {
                                    _activeConversationId = null;
                                    _activeConversationType = ConversationType.proDealCloser;
                                    _conversationKey++;
                                    _proDealCloserInitialMessages = null;
                                  });
                                  _scrollTo(viewportHeight);
                                },
                                onExpressDealmakerPicked: (paths) {
                                  setState(() {
                                    _expressDealmakerItems = paths
                                        .map(
                                          (p) =>
                                              ScreenshotUploadItem(path: p),
                                        )
                                        .toList();
                                    _activeConversationId = null;
                                    _activeConversationType = ConversationType.express;
                                    _activeInitialReplyOptions = null;
                                    _activeInitialKeyword = null;
                                  });
                                },
                                onGetPickupLines: () => _showLinesThatLandTips(context),
                              ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: viewportHeight),
                    child: SizedBox(
                      height: viewportHeight,
                      child: StartWithTextSection(
                        key: ValueKey(_conversationKey),
                        embeddedInScrollView: true,
                        onScrollBackUp: () => _scrollTo(0),
                        initialMessages: _proDealCloserInitialMessages
                            ?.map((m) => ProDealCloserMessage(
                                  text: m.text,
                                  attachmentPaths: List<String>.from(m.attachmentPaths),
                                ))
                            .toList(),
                        onCloseConversation: (messages) {
                          if (messages.isEmpty) return;
                          final now = DateTime.now();
                          final id = _activeConversationType == ConversationType.proDealCloser &&
                                  _activeConversationId != null
                              ? _activeConversationId!
                              : now.millisecondsSinceEpoch.toString();
                          final entity = Conversation(
                            id: id,
                            type: ConversationType.proDealCloser,
                            screenshotPaths: const [],
                            replyOptions: const [],
                            messages: messages,
                            createdAt: now,
                          );
                          di.sl<ConversationRepository>().saveConversation(entity);
                          setState(() {
                            _activeConversationId = id;
                            _activeConversationType = ConversationType.proDealCloser;
                            _proDealCloserInitialMessages = null;
                            _conversationHistory.removeWhere((c) => c.id == id);
                            _conversationHistory.insert(
                              0,
                              _ConversationSnapshot(
                                id: id,
                                type: ConversationType.proDealCloser.name,
                                screenshots: const [],
                                messages: messages
                                    .map((m) => _ProDealCloserMessageSnapshot(
                                          text: m.text,
                                          attachmentPaths: List<String>.from(m.attachmentPaths),
                                        ))
                                    .toList(),
                                createdAt: now,
                              ),
                            );
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}
}

void _showRateUsDialog(BuildContext context, AppLocalizations l10n) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogContext) {
      final config = di.sl<RemoteConfigService>().getRateUsModalConfig();
      final useConfig = config != null &&
          config.buttons.length >= 2 &&
          config.title != null;

      final String title = useConfig
          ? (config!.title is MultilocaleText
              ? (config.title as MultilocaleText).get(dialogContext)
              : config.title?.toString() ?? '')
          : l10n.areYouSatisfied;

      final primaryConfig = useConfig
          ? config!.buttons[1]
          : ButtonConfig(
              text: MultilocaleText({'en': l10n.yes}),
              action: ButtonAction.continueAction,
              buttonColor: '#4ECDC4',
              glowColor: '#4ECDC4',
              glowIntensity: 0.6,
              glowPulse: true,
              buttonStyle: ButtonVisualStyle.glow,
              buttonVisual: 'assets/lottie/magic_stick_pointer.json',
              buttonVisualWidth: 60,
              buttonVisualHeight: 60,
            );
      final secondaryConfig = useConfig
          ? config!.buttons[0]
          : ButtonConfig(
              text: MultilocaleText({'en': l10n.no}),
              action: ButtonAction.continueAction,
              buttonColor: '#9E9E9E',
              glowColor: '#9E9E9E',
              glowIntensity: 0.3,
              buttonStyle: ButtonVisualStyle.glow,
            );

      return Dialog(
        backgroundColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GlassTwoChoiceModal(
            title: title,
            visualPath: useConfig ? config!.visual : 'assets/lottie/star_anim.json',
            visualWidth: useConfig ? config!.visualWidth : 80.0,
            visualHeight: useConfig ? config!.visualHeight : 80.0,
            primaryButtonConfig: primaryConfig,
            onPrimaryPressed: () async {
              Navigator.of(dialogContext).pop();
              final inAppReview = InAppReview.instance;
              if (await inAppReview.isAvailable()) {
                await inAppReview.requestReview();
              }
            },
            secondaryButtonConfig: secondaryConfig,
            onSecondaryPressed: () {
              dialogContext.push(AppRoutes.feedback);
              Navigator.of(dialogContext).pop();
            },
            onClose: () => Navigator.of(dialogContext).pop(),
            borderRadius: BorderRadius.circular(32),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            titleHighlightWords: useConfig ? config?.highlightWords : null,
            titleHighlightColor: useConfig ? config?.highlightColor : null,
          ),
        ),
      );
    },
  );
}

class _HomeDrawer extends StatelessWidget {
  const _HomeDrawer({
    required this.l10n,
    required this.onReferTap,
    this.termsUrl,
    this.privacyUrl,
  });

  final AppLocalizations l10n;
  final VoidCallback onReferTap;
  final String? termsUrl;
  final String? privacyUrl;

  @override
  Widget build(final BuildContext context) => Drawer(
    backgroundColor: Colors.transparent,
    elevation: 0,
    child: ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), // Slightly stronger blur
        child: Container(
          decoration: BoxDecoration(
            // Use a gradient for a more realistic "frosted glass" shine
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.45),
                Colors.white.withValues(alpha: 0.15),
              ],
            ),
            border: Border(
              right: BorderSide(
                color: Colors.white.withValues(alpha: 0.5), // Brighter crisp edge
                width: 1.5,
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Custom Header instead of the bulky default DrawerHeader
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Row(
                    children: [
                      // Optional: Add a little icon or logo next to the title
                      Icon(
                        Icons.auto_awesome,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.appTitle,
                        style: AppTextStyles.headlineSmall.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Subtle divider
                Divider(
                  color: Colors.white.withValues(alpha: 0.4),
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                ),
                const SizedBox(height: 16),

                // Menu Items: Profile, Bargains History, Rate Us, then Logout last (if logged in)
                _buildDrawerItem(
                  context: context,
                  icon: Icons.person_outline,
                  title: l10n.profile,
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to profile
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.history,
                  title: l10n.bargainsHistory,
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to bargains history
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.star_outline,
                  title: l10n.rateUs,
                  onTap: () {
                    Navigator.pop(context);
                    _showRateUsDialog(context, l10n);
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.card_giftcard_rounded,
                  title: l10n.refer,
                  onTap: () {
                    Navigator.pop(context);
                    onReferTap();
                  },
                ),
                if (termsUrl != null && termsUrl!.isNotEmpty)
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.description_outlined,
                    title: l10n.terms,
                    onTap: () {
                      Navigator.pop(context);
                      _launchUrl(termsUrl!);
                    },
                  ),
                if (privacyUrl != null && privacyUrl!.isNotEmpty)
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.privacy_tip_outlined,
                    title: l10n.privacy,
                    onTap: () {
                      Navigator.pop(context);
                      _launchUrl(privacyUrl!);
                    },
                  ),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    if (state is AuthAuthenticated) {
                      return _buildDrawerItem(
                        context: context,
                        icon: Icons.logout,
                        title: l10n.logOut,
                        onTap: () {
                          context.read<AuthBloc>().add(const SignOutRequested());
                          Navigator.pop(context);
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  static Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // Helper widget for cleaner, pill-shaped list items
  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        leading: Icon(icon, color: AppColors.textPrimary),
        title: Text(
          title,
          style: AppTextStyles.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        // Make the tap splash effect blend nicely with the glass
        splashColor: Colors.white.withValues(alpha: 0.3),
        hoverColor: Colors.white.withValues(alpha: 0.1),
        onTap: onTap,
      ),
    );
}

class _ExpressDealmakerHistoryView extends StatelessWidget {
  const _ExpressDealmakerHistoryView({
    required this.l10n,
    required this.conversationHistory,
    required this.onConversationSelected,
    required this.onDelete,
    this.onStartWithText,
    this.onExpressDealmakerPicked,
    this.onGetPickupLines,
  });

  final AppLocalizations l10n;
  final List<_ConversationSnapshot> conversationHistory;
  final ValueChanged<_ConversationSnapshot> onConversationSelected;
  final ValueChanged<_ConversationSnapshot> onDelete;
  final VoidCallback? onStartWithText;
  final ValueChanged<List<String>>? onExpressDealmakerPicked;
  final VoidCallback? onGetPickupLines;

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const crossAxisCount = 3;
                  const spacing = 10.0;
                  const cellWidth = 140.0;
                  const cellHeight = 187.0; // 3:4 aspect
                  final gridWidth =
                      crossAxisCount * cellWidth + (crossAxisCount - 1) * spacing;

                  return SizedBox(
                    width: gridWidth,
                    child: GridView.builder(
                      padding: EdgeInsets.zero,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                        childAspectRatio: cellWidth / cellHeight,
                      ),
                      itemCount: conversationHistory.length,
                      itemBuilder: (context, index) {
                        final snapshot = conversationHistory[index];
                        final firstPath = snapshot.firstImagePath;
                        final bool hasImage = firstPath != null &&
                            firstPath.isNotEmpty &&
                            File(firstPath).existsSync();

                        Widget content;
                        if (hasImage) {
                          content = Image.file(
                            File(firstPath!),
                            fit: BoxFit.cover,
                          );
                        } else {
                          content = Container(
                            color: AppColors.border.withValues(alpha: 0.3),
                            child: Center(
                              child: Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 48,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        }

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Material(
                              elevation: 2,
                              borderRadius: BorderRadius.circular(12),
                              shadowColor: Colors.black26,
                              child: InkWell(
                                onTap: () => onConversationSelected(snapshot),
                                borderRadius: BorderRadius.circular(12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: content,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Material(
                                color: Colors.black54,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  onTap: () => onDelete(snapshot),
                                  customBorder: const CircleBorder(),
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final images = await GalleryPickerHelper.pickImages(context);
                    if (!context.mounted || images.isEmpty) return;
                    final paths = images.map((x) => x.path).toList();
                    onExpressDealmakerPicked?.call(paths);
                  },
                  icon: const Icon(
                    Icons.add_photo_alternate_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                  label: Text(
                    l10n.uploadScreenshot,
                    style: AppTextStyles.buttonText,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.backgroundDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onStartWithText,
                      icon: Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                      label: Text(
                        l10n.enterTextManually,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(
                          color: AppColors.border,
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onGetPickupLines,
                      icon: Icon(
                        Icons.auto_awesome,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                      label: Text(
                        l10n.getPickupLines,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(
                          color: AppColors.border,
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
}

class _EmptyStateContent extends StatelessWidget {
  const _EmptyStateContent({
    required this.l10n,
    this.config,
    this.onStartWithText,
    this.onExpressDealmakerPicked,
    this.onGetPickupLines,
  });

  final AppLocalizations l10n;
  final MainPageConfig? config;
  final VoidCallback? onStartWithText;
  final ValueChanged<List<String>>? onExpressDealmakerPicked;
  final VoidCallback? onGetPickupLines;

  String _headerText(BuildContext context) =>
      (config?.headerText as MultilocaleText?)?.get(context) ??
          l10n.homeEmptyTitle;

  String _uploadText(BuildContext context) =>
      (config?.primaryCtaButton as MultilocaleText?)?.get(context) ??
          l10n.uploadScreenshot;

  String _enterTextText(BuildContext context) =>
      (config?.additionCtaButton as MultilocaleText?)?.get(context) ??
          l10n.enterTextManually;

  String _pickupLinesText(BuildContext context) =>
      (config?.generationCtaButton as MultilocaleText?)?.get(context) ??
          l10n.getPickupLines;

  @override
  Widget build(BuildContext context) {
    final centerVisual = config?.centerVisual;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _headerText(context),
                textAlign: TextAlign.center,
                style: AppTextStyles.headlineSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ),
        if (centerVisual != null)
          VisualAssetWidget(
            visualPath: centerVisual.visual,
            width: centerVisual.width ?? 200,
            height: centerVisual.height ?? 200,
          )
        else
          const SizedBox(height: 200),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.backgroundDark.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final images = await GalleryPickerHelper.pickImages(context);
                      if (!context.mounted || images.isEmpty) return;
                      final paths = images.map((x) => x.path).toList();
                      onExpressDealmakerPicked?.call(paths);
                    },
                    icon: Icon(
                      Icons.add_photo_alternate_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
                    label: Text(
                      _uploadText(context),
                      style: AppTextStyles.buttonText,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.backgroundDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onStartWithText ?? () => context.push(AppRoutes.startWithText),
                      icon: Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                      label: Text(
                        _enterTextText(context),
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(
                            color: AppColors.border, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onGetPickupLines,
                      icon: const Icon(
                        Icons.auto_awesome,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                      label: Text(
                        _pickupLinesText(context),
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(
                            color: AppColors.border, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet for referral benefits – explains rewards and offers share invite link.
/// Content is remote-configurable via [refer_config]; falls back to [l10n] when config is null or empty.
/// Reuses onboarding-style text config: [StyledDescriptionWidget] for benefits and rich title when
/// [refer_config] has [highlight_words] / [highlight_color].
class _ReferBenefitsSheet extends StatelessWidget {
  const _ReferBenefitsSheet({
    required this.l10n,
    this.referConfig,
    required this.onShareInvite,
    required this.onClose,
  });

  final AppLocalizations l10n;
  final ReferConfig? referConfig;
  final VoidCallback onShareInvite;
  final VoidCallback onClose;

  String _title(BuildContext context) {
    if (referConfig != null) {
      final t = referConfig!.getTitle(context);
      if (t.isNotEmpty) return t;
    }
    return l10n.referModalTitle;
  }

  List<String> _benefits(BuildContext context) {
    if (referConfig != null && referConfig!.benefits.isNotEmpty) {
      return referConfig!.getBenefits(context)
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    return [l10n.referBenefit1, l10n.referBenefit2, l10n.referBenefit3];
  }

  String _ctaText(BuildContext context) {
    if (referConfig != null) {
      final t = referConfig!.getCtaButtonText(context);
      if (t.isNotEmpty) return t;
    }
    return l10n.referShareInvite;
  }

  dynamic _getHighlightWordsTitle() {
    if (referConfig?.highlightWords is Map) {
      final v = (referConfig!.highlightWords as Map)['title'];
      if (v != null && (v is! Map || v.isNotEmpty) && (v is! List || v.isNotEmpty)) return v;
    }
    return null;
  }

  dynamic _getHighlightWordsDescription() {
    if (referConfig?.highlightWords is Map) {
      final v = (referConfig!.highlightWords as Map)['description'];
      if (v != null && (v is! Map || v.isNotEmpty) && (v is! List || v.isNotEmpty)) return v;
    }
    return null;
  }

  Color? _getHighlightColor(ColorHelper colorHelper) {
    final s = referConfig?.highlightColor;
    if (s != null && s.isNotEmpty) return colorHelper.getColor(s);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorHelper = di.sl<ColorHelper>();
    final textHighlightHelper = TextHighlightHelper(colorHelper);
    final defaultHighlightColor = _getHighlightColor(colorHelper);
    final highlightWordsTitle = _getHighlightWordsTitle();
    final highlightWordsDescription = _getHighlightWordsDescription();
    final titleText = _title(context);
    final benefits = _benefits(context);
    final useStyledBenefits = highlightWordsDescription != null;
    final textColor = referConfig?.getTextColor(colorHelper) ?? Colors.white;

    return GlassContainer(
      blurSigma: 20.0,
      color: Colors.white,
      opacity: 0.25,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(32),
        topRight: Radius.circular(32),
      ),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.3),
        width: 1.5,
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 40),
              Expanded(
                child: StyledTitleWidget(
                  title: titleText,
                  baseColor: textColor,
                  highlightWordsData: highlightWordsTitle,
                  highlightColor: referConfig?.highlightColor,
                  fontSize: 22,
                  fontSizeHighlight: 24,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 24,
                ),
                onPressed: onClose,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(40, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < benefits.length; i++) ...[
                  useStyledBenefits
                      ? _benefitBulletStyled(
                          context,
                          benefits[i],
                          highlightWordsDescription,
                          defaultHighlightColor,
                          textHighlightHelper,
                          textColor,
                        )
                      : _benefitBullet(benefits[i], textColor),
                  if (i < benefits.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onShareInvite,
                icon: const Icon(Icons.share_rounded, size: 22, color: Colors.white),
                label: Text(
                  _ctaText(context),
                  style: AppTextStyles.buttonText,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.backgroundDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefitBullet(String text, Color textColor) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Icon(
          Icons.check_circle_rounded,
          size: 22,
          color: textColor.withValues(alpha: 0.9),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          text,
          style: AppTextStyles.bodyLarge?.copyWith(
            color: textColor,
            height: 1.4,
          ),
        ),
      ),
    ],
  );

  Widget _benefitBulletStyled(
    BuildContext context,
    String text,
    dynamic highlightWordsData,
    Color? highlightColor,
    TextHighlightHelper textHighlightHelper,
    Color textColor,
  ) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(
              Icons.check_circle_rounded,
              size: 22,
              color: textColor.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StyledDescriptionWidget(
              description: text,
              highlightWordsData: highlightWordsData,
              highlightColor: highlightColor,
              textHighlightHelper: textHighlightHelper,
              textAlign: TextAlign.start,
              onRichTextDescription: (ctx, desc, data) => StyledRichTextDescriptionWidget(
                description: desc,
                highlightWordsData: data,
                baseColor: textColor,
                highlightColor: highlightColor,
                textAlign: TextAlign.start,
                bodyFontSize: 16,
                boldFontSize: 17,
                boldLargeFontSize: 18,
                baseColorOpacity: 1.0,
              ),
            ),
          ),
        ],
      );
}

/// Bottom sheet for "Lines that land" – same style as onboarding sign-in modal (glass, drag handle, close).
class _LinesThatLandBottomSheet extends StatelessWidget {
  const _LinesThatLandBottomSheet({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => GlassContainer(
      blurSigma: 20.0,
      color: Colors.white,
      opacity: 0.25,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(32),
        topRight: Radius.circular(32),
      ),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.3),
        width: 1.5,
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 24,
                ),
                onPressed: onClose,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(40, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.6,
            ),
            child: SingleChildScrollView(
              child: LinesThatLandSheet(
                onClose: onClose,
                showHeader: false,
              ),
            ),
          ),
        ],
      ),
    );
}

/// Simple message representation for Pro Deal Closer snapshot (UI only).
class _ProDealCloserMessageSnapshot {
  _ProDealCloserMessageSnapshot({required this.text, this.attachmentPaths = const []});
  final String text;
  final List<String> attachmentPaths;
}

class _ConversationSnapshot {
  _ConversationSnapshot({
    required this.id,
    required this.type,
    required this.screenshots,
    this.replyOptions = const [],
    this.keyword,
    this.messages = const [],
    required this.createdAt,
  });

  final String id;
  final String type;
  final List<ScreenshotUploadItem> screenshots;
  final List<String> replyOptions;
  final String? keyword;
  final List<_ProDealCloserMessageSnapshot> messages;
  final DateTime createdAt;

  /// First image path for history thumbnail: express = first screenshot, pro = first attachment from messages.
  String? get firstImagePath {
    if (screenshots.isNotEmpty) return screenshots.first.path;
    for (final m in messages) {
      if (m.attachmentPaths.isNotEmpty) return m.attachmentPaths.first;
    }
    return null;
  }
}

