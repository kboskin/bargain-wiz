import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/features/express_dealmaker/domain/entities/deal_reply.dart';
import 'package:appwizard/features/express_dealmaker/domain/repositories/express_dealmaker_repository.dart';
import 'package:appwizard/core/error/failures.dart';
import 'package:dartz/dartz.dart' show Either;
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/theme/app_text_styles.dart';
import 'package:appwizard/core/widgets/scanning_overlay.dart';
import 'package:appwizard/core/widgets/glass_container.dart';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';
import 'package:appwizard/core/utils/gallery_picker_helper.dart';
import 'package:appwizard/l10n/app_localizations.dart';
import 'package:appwizard/features/express_dealmaker/presentation/pages/screenshot_upload_item.dart';

/// Simple mode (Express Dealmaker): drop screenshot(s), per-item upload state,
/// scan overlay while uploading, larger cards when uploading / smaller when done,
/// retry on failed. Multi-asset selection supported.
class SimpleModeSection extends StatefulWidget {
  const SimpleModeSection({
    super.key,
    required this.screenshotItems,
    required this.onBack,
    required this.onAddPaths,
    required this.onItemStatusChange,
    required this.expressDealmakerRepository,
    this.initialReplyOptions,
    this.initialKeyword,
    this.onCloseConversation,
  });

  final List<ScreenshotUploadItem> screenshotItems;
  final VoidCallback onBack;
  final ValueChanged<List<String>> onAddPaths;
  final void Function(int index, ScreenshotUploadStatus status) onItemStatusChange;
  final ExpressDealmakerRepository expressDealmakerRepository;
  final List<String>? initialReplyOptions;
  final String? initialKeyword;
  final void Function(List<ScreenshotUploadItem> screenshots, List<String>? replyOptions, String? keyword)? onCloseConversation;

  @override
  State<SimpleModeSection> createState() => _SimpleModeSectionState();
}

class _SimpleModeSectionState extends State<SimpleModeSection>
    with SingleTickerProviderStateMixin {
  final TextEditingController _keywordController = TextEditingController();
  final FocusNode _keywordFocusNode = FocusNode();
  /// Indices for which we've started an upload and not yet completed (success/failed).
  final Set<int> _uploadStarted = {};
  ExpressDealmakerRepository get _repo => widget.expressDealmakerRepository;

  /// Reply options from backend (multiple deals). Null = not loaded, empty = none, non-empty = show list.
  List<String>? _replyOptions;
  bool _replyLoading = false;
  /// True when getDealReply failed (e.g. connectivity); show Retry and allow retry.
  bool _replyFailed = false;
  /// Prevents auto-fetch from running more than once per "batch"; reset when user adds more screenshots.
  bool _autoFetchTriggered = false;

  late final AnimationController _hintController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _hintOffset = Tween<double>(begin: 0, end: -4)
      .animate(CurvedAnimation(parent: _hintController, curve: Curves.easeInOut));
  @override
  void dispose() {
    _keywordController.dispose();
    _keywordFocusNode.dispose();
    _hintController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _replyOptions = widget.initialReplyOptions;
    final initialKeyword = widget.initialKeyword;
    if (initialKeyword != null && initialKeyword.isNotEmpty) {
      _keywordController.text = initialKeyword;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _startUploadsForPending());
  }

  void _startUploadsForPending() {
    if (!mounted) return;
    final items = widget.screenshotItems;
    for (var i = 0; i < items.length; i++) {
      if (items[i].status != ScreenshotUploadStatus.uploading) continue;
      if (_uploadStarted.contains(i)) continue;
      _uploadStarted.add(i);
      _runUpload(i);
    }
  }

  /// Upload via repository; on success/failure notify parent.
  Future<void> _runUpload(int index) async {
    final items = widget.screenshotItems;
    if (index >= items.length) return;
    final path = items[index].path;
    final result = await _repo.uploadScreenshot(path);
    if (!mounted) return;
    _uploadStarted.remove(index);
    if (index >= widget.screenshotItems.length) return;
    result.fold(
      (_) => widget.onItemStatusChange(index, ScreenshotUploadStatus.failed),
      (_) => widget.onItemStatusChange(index, ScreenshotUploadStatus.success),
    );
  }

  Future<void> _pickAndAdd() async {
    final picked = await GalleryPickerHelper.pickImages(context);
    if (!mounted || picked.isEmpty) return;
    widget.onAddPaths(picked.map((x) => x.path).toList());
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }

  bool get _anyUploading => widget.screenshotItems
      .any((e) => e.status == ScreenshotUploadStatus.uploading);

  /// True when every screenshot is still uploading (initial add). When adding more later, we keep the normal UI.
  bool get _allUploading => widget.screenshotItems.isNotEmpty &&
      widget.screenshotItems.every((e) => e.status == ScreenshotUploadStatus.uploading);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final config = di.sl<RemoteConfigService>().getMainPageConfig();
    final hasScreenshots = widget.screenshotItems.isNotEmpty;
    final uploadingOnly = hasScreenshots && _allUploading;

    String _hintKeyword(BuildContext ctx) =>
        (config?.expressDealmakerKeywordHint as MultilocaleText?)?.get(ctx) ??
        l10n.expressDealmakerKeywordHint;
    String _hintTapReply(BuildContext ctx) =>
        (config?.expressDealmakerTapReplyHint as MultilocaleText?)?.get(ctx) ??
        l10n.tapReplyToCopy;

    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: uploadingOnly
                  ? Center(
                      child: _buildScreenshotStack(context, centerContent: true),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!hasScreenshots) _buildDropZone(context, l10n)
                          else ...[
                            _buildScreenshotStack(context),
                            const SizedBox(height: 16),
                            Center(
                              child: OutlinedButton.icon(
                                onPressed: _anyUploading ? null : _pickAndAdd,
                                icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
                                label: Text(l10n.simpleModeAddScreenshot),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.textPrimary,
                                  side: BorderSide(color: AppColors.border),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _keywordController,
                              focusNode: _keywordFocusNode,
                              decoration: InputDecoration(
                                hintText: _hintKeyword(context),
                                hintStyle: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: AppColors.border),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                            ),
                          ],
                          const SizedBox(height: 20),
                          Center(
                            child: AnimatedBuilder(
                              animation: _hintController,
                              builder: (context, child) => Transform.translate(
                                offset: Offset(0, _hintOffset.value),
                                child: child,
                              ),
                              child: Text(
                                '👇 ${_hintTapReply(context)} 👇',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildReplyCard(l10n),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
            ),
            if (!uploadingOnly) _buildBottomBar(context, l10n),
          ],
        ),
        Positioned(
          left: 0,
          top: 0,
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 20, 4),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: IconButton(
                  onPressed: () {
                    try {
                      widget.onCloseConversation?.call(
                        List<ScreenshotUploadItem>.from(widget.screenshotItems),
                        _replyOptions,
                        _keywordController.text.isNotEmpty ? _keywordController.text : null,
                      );
                    } catch (_) {}
                    widget.onBack();
                  },
                  icon: const Icon(Icons.chevron_left),
                  color: AppColors.textPrimary,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    padding: const EdgeInsets.all(8),
                  ),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropZone(BuildContext context, AppLocalizations l10n) {
    return GestureDetector(
      onTap: _pickAndAdd,
      child: Container(
        height: 200,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.border,
            width: 2,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.simpleModeDropHint,
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(SimpleModeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startUploadsForPending();
    // When user adds more screenshots, allow auto-fetch again once they finish.
    if (widget.screenshotItems.length > oldWidget.screenshotItems.length) {
      _autoFetchTriggered = false;
    }
    _maybeAutoFetchReply();
  }

  /// If all uploads are done, at least one success, and we haven't fetched yet → fetch reply.
  void _maybeAutoFetchReply() {
    if (_autoFetchTriggered || _replyLoading) return;
    final successPaths = widget.screenshotItems
        .where((e) => e.status == ScreenshotUploadStatus.success)
        .map((e) => e.path)
        .toList();
    if (successPaths.isEmpty || _anyUploading) return;
    _autoFetchTriggered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onGetMore(Localizations.localeOf(context).languageCode);
    });
  }

  /// Main gallery: up to [kMainGalleryCount] items in a 2-column grid. Rest in a horizontal strip below.
  Widget _buildScreenshotStack(BuildContext context, {bool centerContent = false}) {
    final screenSize = MediaQuery.sizeOf(context);
    final items = widget.screenshotItems;
    if (items.isEmpty) return const SizedBox.shrink();

    final padding = 20.0 * 2;
    const aspectRatio = 3 / 4;
    final gridWidth = screenSize.width - padding;
    const spacing = 8.0;

    // First row: as many large items as fit in a single row.
    // We target a "nice" width and then compute how many fit.
    const desiredCardWidth = 140.0;
    var maxPerRow = (gridWidth / desiredCardWidth).floor();
    if (maxPerRow < 1) maxPerRow = 1;
    if (maxPerRow > items.length) maxPerRow = items.length;

    final mainCount = maxPerRow;
    final mainItems = items.sublist(0, mainCount);
    final stripItems = mainCount < items.length ? items.sublist(mainCount) : <ScreenshotUploadItem>[];

    final cardWidth = mainCount == 0
        ? 0.0
        : (gridWidth - spacing * (mainCount - 1)) / mainCount;
    final cardHeight = cardWidth / aspectRatio;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top: grid of as many as fit (up to kMainGalleryCount)
        Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < mainItems.length; i++)
              SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: _buildScreenshotCard(
                  context,
                  mainItems[i],
                  i,
                  cardHeight,
                  cardWidth,
                  number: i + 1,
                ),
              ),
          ],
        ),
        if (stripItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          // Bottom: smaller frames. If they all fit, center them in a row.
          // If they don't fit, show a horizontal scrollable gallery.
          SizedBox(
            height: 88,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const smallW = 64.0;
                const smallH = 88.0 - 8;
                const gap = 8.0;
                final totalWidth =
                    stripItems.length * smallW + (stripItems.length - 1) * gap;

                if (totalWidth <= constraints.maxWidth) {
                  // Centered row when everything fits.
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var index = 0; index < stripItems.length; index++)
                        Padding(
                          padding: EdgeInsets.only(
                            right: index == stripItems.length - 1 ? 0 : gap,
                          ),
                          child: _buildScreenshotCard(
                            context,
                            stripItems[index],
                            mainCount + index,
                            smallH,
                            smallW,
                            number: mainCount + index + 1,
                          ),
                        ),
                    ],
                  );
                }

                // Fall back to scrollable strip when there are many.
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: stripItems.length,
                  itemBuilder: (context, index) {
                    final globalIndex = mainCount + index;
                    final item = stripItems[index];
                    return Padding(
                      padding: EdgeInsets.only(right: index == stripItems.length - 1 ? 0 : gap),
                      child: _buildScreenshotCard(
                        context,
                        item,
                        globalIndex,
                        smallH,
                        smallW,
                        number: globalIndex + 1,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildScreenshotCard(
    BuildContext context,
    ScreenshotUploadItem item,
    int index,
    double cardHeight,
    double cardWidth, {
    required int number,
  }) {
    final isUploading = item.status == ScreenshotUploadStatus.uploading;
    final isFailed = item.status == ScreenshotUploadStatus.failed;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ImageWithScanningOverlay(
          width: cardWidth,
          height: cardHeight,
          borderRadius: 12,
          isUploading: isUploading,
          child: Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(12),
            shadowColor: Colors.black26,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(item.path),
                width: cardWidth,
                height: cardHeight,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        Positioned(
          left: 6,
          top: 6,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.backgroundDark,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: AppTextStyles.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        if (isFailed)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Material(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => widget.onItemStatusChange(index, ScreenshotUploadStatus.uploading),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          AppLocalizations.of(context)!.retry,
                          style: AppTextStyles.labelSmall?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReplyCard(AppLocalizations l10n) {
    final options = _replyOptions;
    final isLoading = _replyLoading;
    final hasOptions = options != null && options.isNotEmpty;

    if (isLoading) {
      return _buildLoadingCard();
    }
    if (!hasOptions) {
      return _buildPlaceholderCard(l10n);
    }
    return _DealsAnimatedList(
      options: options!,
      onCopy: _copyToClipboard,
    );
  }

  Widget _buildLoadingCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderCard(AppLocalizations l10n) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Text(
            l10n.linesPlaceholder,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final successPaths = widget.screenshotItems
        .where((e) => e.status == ScreenshotUploadStatus.success)
        .map((e) => e.path)
        .toList();
    final canRequestReply = successPaths.isNotEmpty && !_replyLoading;
    final isRetry = _replyFailed;
    final buttonLabel = isRetry ? l10n.retry : l10n.getMore;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: canRequestReply
                ? () => _onGetMore(Localizations.localeOf(context).languageCode)
                : null,
            icon: Text(isRetry ? '🔄' : '✨', style: const TextStyle(fontSize: 16)),
            label: Text(
              buttonLabel,
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.backgroundDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onGetMore(String locale) async {
    final successPaths = widget.screenshotItems
        .where((e) => e.status == ScreenshotUploadStatus.success)
        .map((e) => e.path)
        .toList();
    if (successPaths.isEmpty) return;
    setState(() {
      _replyLoading = true;
      _replyFailed = false;
    });
    final keyword = _keywordController.text.trim().isEmpty ? null : _keywordController.text.trim();
    Either<Failure, DealReply> result;
    try {
      result = await _repo.getDealReply(
        uploadedIds: successPaths,
        keyword: keyword,
        locale: locale,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _replyLoading = false;
        _replyFailed = true;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _replyLoading = false;
      result.fold(
        (_) {
          _replyFailed = true;
          _replyOptions = null;
        },
        (reply) {
          _replyFailed = false;
          _replyOptions = reply.options.isEmpty
              ? ['Here’s your deal reply.']
              : reply.options;
        },
      );
    });
  }
}

/// Animated list of deal options with stagger entrance (same as onboarding select).
class _DealsAnimatedList extends StatefulWidget {
  const _DealsAnimatedList({
    required this.options,
    required this.onCopy,
  });

  final List<String> options;
  final ValueChanged<String> onCopy;

  @override
  State<_DealsAnimatedList> createState() => _DealsAnimatedListState();
}

class _DealsAnimatedListState extends State<_DealsAnimatedList>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  final List<Animation<double>> _itemAnimations = [];

  @override
  void initState() {
    super.initState();
    final itemCount = widget.options.length;
    final totalDuration = itemCount * 250;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalDuration),
    );
    for (int i = 0; i < itemCount; i++) {
      final start = i / itemCount;
      final end = (i + 1) / itemCount;
      _itemAnimations.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(start, end, curve: Curves.easeOutCubic),
          ),
        ),
      );
    }
    _controller.forward();
  }

  @override
  void didUpdateWidget(_DealsAnimatedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options != widget.options) {
      _controller.dispose();
      final itemCount = widget.options.length;
      final totalDuration = itemCount * 250;
      _controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: totalDuration),
      );
      _itemAnimations.clear();
      for (int i = 0; i < itemCount; i++) {
        final start = i / itemCount;
        final end = (i + 1) / itemCount;
        _itemAnimations.add(
          Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: _controller,
              curve: Interval(start, end, curve: Curves.easeOutCubic),
            ),
          ),
        );
      }
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.options.isEmpty) return const SizedBox.shrink();
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: widget.options.length,
      itemBuilder: (context, index) {
        final option = widget.options[index];
        final animation = index < _itemAnimations.length
            ? _itemAnimations[index]
            : const AlwaysStoppedAnimation(1.0);
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Opacity(
              opacity: animation.value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - animation.value)),
                child: Transform.scale(
                  scale: 0.8 + (0.2 * animation.value),
                  child: child,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _DealCard(
              text: option,
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onCopy(option);
              },
            ),
          ),
        );
      },
    );
  }
}

class _DealCard extends StatelessWidget {
  const _DealCard({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onTap,
        borderRadius: BorderRadius.circular(12),
        child: GlassContainer(
          blurSigma: 24.0,
          color: Colors.white,
          opacity: 0.28,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.4),
            width: 1.0,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  text,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.content_copy_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
