import 'package:flutter/material.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/wiz/frosted_surface.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';
import 'package:appwizard/features/conversation/domain/helpers/conversation_labels.dart';
import 'package:appwizard/features/history/presentation/history_copy.dart';
import 'package:appwizard/features/history/presentation/widgets/history_status_chip.dart';
import 'package:appwizard/features/history/presentation/widgets/history_thumbnail.dart';

/// Frosted history row: thumbnail · title / "{marketplace} · {date}" / price · status chip.
/// Swipe left to delete when [onDismissed] is given; long-press for [onLongPress].
class HistoryRow extends StatelessWidget {
  const HistoryRow({
    super.key,
    required this.conversation,
    required this.onTap,
    this.onLongPress,
    this.onDismissed,
    this.now,
    this.marketplaceLabel,
  });

  final Conversation conversation;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDismissed;
  /// Reference time for the relative date (tests); defaults to `DateTime.now()`.
  final DateTime? now;

  /// Label configured for the conversation's marketplace; the stored value is shown when the
  /// config no longer offers it, and "Any marketplace" when there is none.
  final String? marketplaceLabel;

  static const TextStyle _metaStyle = TextStyle(
    fontFamily: WizType.bodyFont,
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w400,
    color: WizColors.textSecondary,
  );

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final title = ConversationLabels.title(context, c);
    final marketplace = switch ((marketplaceLabel, c.marketplace)) {
      (final String label, _) when label.isNotEmpty => label,
      (_, final String value) when value.isNotEmpty => value,
      _ => ConversationLabels.of(context, ConversationLabels.anyMarketplace),
    };
    final date = ConversationLabels.date(context, c.createdAt, now: now);
    final price = ConversationLabels.priceLine(context, c);

    final card = WizPressable(
      onTap: onTap,
      onLongPress: onLongPress,
      scale: 0.985,
      child: FrostedSurface(
        radius: WizRadii.card,
        padding: const EdgeInsets.all(10),
        shadow: WizShadows.cardSoft,
        child: Row(
          children: [
            HistoryThumbnail(conversation: c),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: WizType.cardTitle,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$marketplace · $date',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _metaStyle,
                  ),
                  if (price != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      price,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: WizType.captionStrong,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            HistoryStatusChip(status: c.status),
          ],
        ),
      ),
    );

    if (onDismissed == null) return card;
    return Dismissible(
      key: ValueKey('history-row-${c.id}'),
      direction: DismissDirection.endToStart,
      background: _DeleteBackground(label: HistoryCopy.of(context, HistoryCopy.deleteAction)),
      onDismissed: (_) => onDismissed!(),
      child: card,
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: WizColors.error,
          borderRadius: BorderRadius.circular(WizRadii.card),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 6),
            Text(label, style: WizType.bodySmBold.copyWith(color: Colors.white)),
          ],
        ),
      );
}
