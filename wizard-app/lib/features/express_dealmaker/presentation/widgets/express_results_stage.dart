import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:appwizard/core/theme/option_style.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/core/widgets/wiz/fade_up.dart';
import 'package:appwizard/core/widgets/wiz/frosted_surface.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/core/widgets/wiz/wiz_chip.dart';
import 'package:appwizard/core/widgets/wiz/wiz_text_field.dart';
import 'package:appwizard/features/express_dealmaker/presentation/cubit/express_dealmaker_state.dart';
import 'package:appwizard/features/express_dealmaker/presentation/express_copy.dart';
import 'package:appwizard/features/profile/domain/profile_fields.dart';
import 'package:appwizard/features/express_dealmaker/presentation/widgets/reply_card.dart';
import 'package:appwizard/features/express_dealmaker/presentation/widgets/screenshot_tile.dart';

/// 5d Results: thumbnail strip + "Seeing: …", keyword field, override chips, bobbing
/// hint, staggered reply cards and a sticky "✨ Get More" over a bottom fade.
class ExpressResultsStage extends StatefulWidget {
  const ExpressResultsStage({
    required this.state,
    required this.copy,
    required this.scoped,
    required this.onPick,
    required this.onRetryUpload,
    required this.onKeywordChanged,
    required this.onOverride,
    required this.onGetMore,
    super.key,
  });

  static const int stripCount = 3;
  static const double thumbWidth = 64;
  static const double thumbHeight = 85;
  static const double bottomSpacer = 110;

  final ExpressDealmakerState state;
  final ExpressCopy copy;
  /// The answers this deal may override — whatever the template marks
  /// `scope: "conversation"` — each with the options, labels, colours and glyphs it offers.
  final List<ProfileField> scoped;
  final VoidCallback onPick;
  final ValueChanged<int> onRetryUpload;
  final ValueChanged<String> onKeywordChanged;
  /// One conversation-scoped answer changed: `(answer key, picked value)`.
  final void Function(String key, dynamic value) onOverride;
  final VoidCallback onGetMore;

  @override
  State<ExpressResultsStage> createState() => _ExpressResultsStageState();
}

class _ExpressResultsStageState extends State<ExpressResultsStage> {
  late final TextEditingController _keyword = TextEditingController(text: widget.state.keyword);
  final FocusNode _keywordFocus = FocusNode();

  @override
  void didUpdateWidget(covariant final ExpressResultsStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync external keyword changes (e.g. restored conversation) while not typing.
    if (!_keywordFocus.hasFocus && widget.state.keyword != _keyword.text) {
      _keyword.text = widget.state.keyword;
    }
  }

  @override
  void dispose() {
    _keyword.dispose();
    _keywordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    final state = widget.state;
    final copy = widget.copy;
    final bottom = math.max(MediaQuery.paddingOf(context).bottom, 20.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(WizSpacing.gutter, 4, WizSpacing.gutter, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStrip(context),
              const SizedBox(height: WizSpacing.stack),
              _buildSeeing(),
              const SizedBox(height: WizSpacing.stackLg),
              WizTextField(
                controller: _keyword,
                focusNode: _keywordFocus,
                height: 48,
                hintText: copy.keywordHint,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
                style: WizType.fieldText.copyWith(fontWeight: FontWeight.w500),
                onChanged: widget.onKeywordChanged,
                onSubmitted: (_) => _keywordFocus.unfocus(),
              ),
              const SizedBox(height: WizSpacing.stack),
              _buildToneChips(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                child: Bob(
                  child: Text(
                    '👇 ${copy.tapReplyHint} 👇',
                    textAlign: TextAlign.center,
                    style: WizType.captionStrong.copyWith(color: WizColors.textSecondary),
                  ),
                ),
              ),
              _buildCards(),
              const SizedBox(height: ExpressResultsStage.bottomSpacer),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(WizSpacing.gutter, 18, WizSpacing.gutter, bottom),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00E7F6F8), Color(0xF2E7F6F8)],
                stops: [0, 0.4],
              ),
            ),
            child: WizPrimaryButton(
              label: '✨ ${copy.getMore}',
              loading: state.replyLoading,
              onPressed: state.replyLoading ? null : widget.onGetMore,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStrip(final BuildContext context) {
    final items = widget.state.screenshots;
    final head = items.take(ExpressResultsStage.stripCount).toList();
    final more = items.length - head.length;
    return Row(
      children: [
        for (var i = 0; i < head.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: WizSpacing.stack),
            child: ScreenshotTile(
              key: ValueKey('strip-${head[i].path}'),
              path: head[i].path,
              number: i + 1,
              width: ExpressResultsStage.thumbWidth,
              height: ExpressResultsStage.thumbHeight,
              radius: WizRadii.thumb,
              badgeSize: 16,
              badgeInset: 4,
              scanning: head[i].isUploading,
              failed: head[i].isFailed,
              onRetry: () => widget.onRetryUpload(i),
              shadow: WizShadows.cardSoft,
            ),
          ),
        if (more > 0)
          MoreTile(
            count: more,
            width: ExpressResultsStage.thumbWidth,
            height: ExpressResultsStage.thumbHeight,
            radius: WizRadii.thumb,
            fontSize: 15,
            onTap: widget.onPick,
          )
        else
          AddTile(
            width: ExpressResultsStage.thumbWidth,
            height: ExpressResultsStage.thumbHeight,
            radius: WizRadii.thumb,
            iconSize: 20,
            onTap: widget.onPick,
            semanticLabel: widget.copy.addScreenshot,
          ),
      ],
    );
  }

  Widget _buildSeeing() {
    final seeing = widget.state.seeing;
    if (seeing == null || seeing.isEmpty) return const SizedBox.shrink();
    return Text.rich(
      TextSpan(
        style: WizType.caption,
        children: [
          TextSpan(text: '${widget.copy.seeingPrefix} '),
          TextSpan(
            text: seeing,
            style: WizType.caption.copyWith(fontWeight: FontWeight.w700, color: WizColors.ink),
          ),
        ],
      ),
    );
  }

  /// One scrollable row of chips per conversation-scoped answer, in screen order. Nothing
  /// here knows what any of them mean: an answer marked `scope: "conversation"` in remote
  /// config gets a row the day it lands.
  Widget _buildToneChips(final BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var f = 0; f < widget.scoped.length; f++) ...[
            if (f > 0) const SizedBox(height: 6),
            _chipRow(context, widget.scoped[f]),
          ],
        ],
      );

  Widget _chipRow(final BuildContext context, final ProfileField field) {
    final selected = widget.state.overrides[field.key];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < field.options.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            if (field.options[i] case final option)
              if (OptionStyle.of(option) case final style)
                WizChip(
                  label: TemplateText.textOf(context, option.shortLabel ?? option.label),
                  // The option's glyph; inherits the chip foreground when selected (filled in its colour).
                  leading: style.icon == null
                      ? null
                      : Icon(
                          style.icon,
                          color: option.value == '$selected' ? null : style.textColor,
                        ),
                  compact: true,
                  selected: option.value == '$selected',
                  selectedColor: style.color,
                  selectedTextColor: style.textOnColor,
                  fill: Colors.white,
                  onTap: () => widget.onOverride(field.key, ProfileFields.storedValue(field, option.value)),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildCards() {
    final state = widget.state;
    final cards = KeyedSubtree(
      key: ValueKey('replies-${state.requestId}'),
      child: StaggeredFadeUpColumn(
        stagger: WizMotion.replyStagger,
        duration: WizMotion.replyEnter,
        children: [
          for (var i = 0; i < state.lines.length; i++)
            ReplyCard(
              key: ValueKey('reply-${state.requestId}-$i'),
              index: i,
              line: state.lines[i],
              copy: widget.copy,
            ),
        ],
      ),
    );
    if (!state.replyLoading) return cards;
    return Stack(
      alignment: Alignment.center,
      children: [
        IgnorePointer(child: Opacity(opacity: 0.35, child: cards)),
        Positioned.fill(
          child: Center(
            child: FrostedSurface(
              radius: WizRadii.chip,
              color: WizColors.frostedDialog,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: WizColors.purple),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      widget.copy.uploadingStatus,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: WizType.statusSm,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
