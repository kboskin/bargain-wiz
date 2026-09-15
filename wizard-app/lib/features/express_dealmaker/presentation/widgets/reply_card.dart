import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/wiz/frosted_surface.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/core/widgets/wiz/wiz_toast.dart';
import 'package:appwizard/features/conversation/domain/entities/deal_line.dart';
import 'package:appwizard/features/express_dealmaker/presentation/express_copy.dart';

/// Frosted reply card: intent tag, line, 👍 👎, "Why this works" toggle and a
/// copy circle. Tap or long-press anywhere copies the line (teal "copied" state,
/// light haptic, toast, reverts after [WizMotion.copiedHold]).
class ReplyCard extends StatefulWidget {
  const ReplyCard({
    required this.index,
    required this.line,
    required this.copy,
    super.key,
  });

  final int index;
  final DealLine line;
  final ExpressCopy copy;

  /// Text color of the intent tag per [DealIntent].
  static Color intentColor(final DealIntent intent) {
    switch (intent) {
      case DealIntent.opener:
        return WizColors.intentOpener;
      case DealIntent.counter:
        return WizColors.intentCounter;
      case DealIntent.close:
        return WizColors.intentClose;
      case DealIntent.other:
        return WizColors.textTertiary;
    }
  }

  @override
  State<ReplyCard> createState() => _ReplyCardState();
}

class _ReplyCardState extends State<ReplyCard> {
  bool _copied = false;
  bool _showWhy = false;
  /// null = no feedback, true = liked, false = disliked.
  bool? _liked;
  Timer? _revert;

  @override
  void dispose() {
    _revert?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    unawaited(HapticFeedback.lightImpact());
    await Clipboard.setData(ClipboardData(text: widget.line.text));
    if (!mounted) return;
    WizToast.show(context, widget.copy.copiedToast);
    setState(() => _copied = true);
    _revert?.cancel();
    _revert = Timer(WizMotion.copiedHold, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _like() => setState(() => _liked = true);

  void _dislike() {
    setState(() => _liked = false);
    WizToast.show(context, widget.copy.dislikeToast);
  }

  void _toggleWhy() => setState(() => _showWhy = !_showWhy);

  @override
  Widget build(final BuildContext context) {
    final line = widget.line;
    final tagColor = ReplyCard.intentColor(line.intent);
    final number = (widget.index + 1).toString().padLeft(2, '0');
    final why = line.why;

    return WizPressable(
      onTap: _copy,
      onLongPress: _copy,
      scale: 0.985,
      child: FrostedSurface(
        color: _copied ? WizColors.tealCopied : WizColors.frosted,
        borderColor: _copied ? WizColors.teal : WizColors.frostedBorder,
        borderWidth: 1.5,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$number · ${line.intent.label.toUpperCase()}',
                    style: WizType.intentTag.copyWith(color: tagColor),
                  ),
                  const SizedBox(height: 6),
                  Text(line.text, style: WizType.replyLine),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _FeedbackPill(
                        emoji: '👍',
                        background: (_liked ?? false) ? WizColors.likedBg : WizColors.inkFaint,
                        onTap: _like,
                      ),
                      const SizedBox(width: 6),
                      _FeedbackPill(
                        emoji: '👎',
                        background: !(_liked ?? true) ? WizColors.dislikedBg : WizColors.inkFaint,
                        onTap: _dislike,
                      ),
                      if (why != null && why.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: WizTextLink(
                            label: _showWhy ? widget.copy.hideLabel : widget.copy.whyLabel,
                            style: WizType.chip,
                            onPressed: _toggleWhy,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_showWhy && why != null && why.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: WizColors.purpleSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        why,
                        style: WizType.caption.copyWith(color: WizColors.purpleInk),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _copied ? WizColors.teal : WizColors.inkSoft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                _copied ? Icons.check_rounded : Icons.copy_rounded,
                size: 18,
                color: _copied ? Colors.white : WizColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackPill extends StatelessWidget {
  const _FeedbackPill({
    required this.emoji,
    required this.background,
    required this.onTap,
  });

  final String emoji;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(WizRadii.chip),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 13, height: 1.3)),
        ),
      );
}
