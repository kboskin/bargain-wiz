import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/routing/app_routes.dart';
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/utils/gallery_picker_helper.dart';
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/theme/app_text_styles.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/data/models/multilocale_text.dart';
import 'package:appwizard/data/models/remote_config/main_page_config.dart';
import 'package:appwizard/data/models/remote_config/share_config.dart';
import 'package:appwizard/l10n/app_localizations.dart';
import 'package:appwizard/presentation/bloc/auth/auth_bloc.dart';
import 'package:appwizard/presentation/bloc/auth/auth_event.dart';
import 'package:appwizard/presentation/bloc/auth/auth_state.dart';
import 'package:appwizard/presentation/pages/start_with_text/start_with_text_page.dart';
import 'package:appwizard/presentation/pages/home/simple_mode_section.dart';
import 'package:appwizard/presentation/pages/home/screenshot_upload_item.dart';
import 'package:appwizard/domain/repositories/express_dealmaker_repository.dart';
import 'package:appwizard/domain/repositories/conversation_repository.dart';
import 'package:appwizard/domain/entities/conversation.dart' show Conversation, ConversationType, ProDealCloserMessage;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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
    _scrollController.addListener(_onScrollChanged);
    _loadConversationHistory();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    super.dispose();
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
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.backgroundDark.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
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
      drawer: _HomeDrawer(l10n: l10n),
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

class _HomeDrawer extends StatelessWidget {
  const _HomeDrawer({required this.l10n});

  final AppLocalizations l10n;

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

                // Menu Items
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
  });

  final AppLocalizations l10n;
  final List<_ConversationSnapshot> conversationHistory;
  final ValueChanged<_ConversationSnapshot> onConversationSelected;
  final ValueChanged<_ConversationSnapshot> onDelete;
  final VoidCallback? onStartWithText;
  final ValueChanged<List<String>>? onExpressDealmakerPicked;

  @override
  Widget build(BuildContext context) {
    return Column(
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
                      onPressed: () {
                        // TODO: Get pickup lines from history view
                      },
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
}

class _EmptyStateContent extends StatelessWidget {
  const _EmptyStateContent({
    required this.l10n,
    this.config,
    this.onStartWithText,
    this.onExpressDealmakerPicked,
  });

  final AppLocalizations l10n;
  final MainPageConfig? config;
  final VoidCallback? onStartWithText;
  final ValueChanged<List<String>>? onExpressDealmakerPicked;

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
                      onPressed: () {
                        // TODO: Get pickup lines
                      },
                      icon: Icon(
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

