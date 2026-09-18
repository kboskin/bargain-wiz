
import 'package:flutter/material.dart';

import 'package:appwizard/core/widgets/attachment_image.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/wiz/fade_up.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/features/conversation/domain/entities/conversation.dart';

/// Home history grid: 3 columns, gap 10, 3:4 tiles radius 14, staggered 60ms FadeUp.
/// Shows at most [maxTiles] conversations.
class HistoryGrid extends StatelessWidget {
  const HistoryGrid({
    super.key,
    required this.conversations,
    required this.onOpen,
    required this.onDelete,
    this.untitledLabel = 'Untitled deal',
    this.maxTiles = 6,
  });

  final List<Conversation> conversations;
  final ValueChanged<Conversation> onOpen;
  final ValueChanged<Conversation> onDelete;
  final String untitledLabel;
  final int maxTiles;

  @override
  Widget build(BuildContext context) {
    final items = conversations.take(maxTiles).toList(growable: false);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 3 / 4,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => FadeUp(
        key: ValueKey(items[i].id),
        delay: WizMotion.historyStagger * i,
        child: HistoryTile(
          conversation: items[i],
          untitledLabel: untitledLabel,
          onTap: () => onOpen(items[i]),
          onDelete: () => onDelete(items[i]),
        ),
      ),
    );
  }
}

/// One 3:4 tile: thumbnail (or purple diagonal stripes for text-only deals),
/// bottom-left title chip, top-right 22px ✕.
class HistoryTile extends StatelessWidget {
  const HistoryTile({
    super.key,
    required this.conversation,
    required this.onTap,
    required this.onDelete,
    this.untitledLabel = 'Untitled deal',
  });

  final Conversation conversation;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final String untitledLabel;

  @override
  Widget build(BuildContext context) {
    final path = conversation.thumbnailPath;
    final title = (conversation.title ?? '').trim().isEmpty ? untitledLabel : conversation.title!.trim();
    return WizPressable(
      onTap: onTap,
      scale: 0.985,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(WizRadii.thumbLg),
          boxShadow: WizShadows.cardSoft,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (path != null && path.isNotEmpty)
              AttachmentImage(
                path: path,
                fit: BoxFit.cover,
                placeholder: const StripePlaceholder(),
                errorWidget: const StripePlaceholder(),
              )
            else
              const StripePlaceholder(),
            Positioned(
              left: 6,
              bottom: 6,
              right: 26,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: WizType.bodyFont,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: WizColors.ink,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Semantics(
                button: true,
                label: MaterialLocalizations.of(context).deleteButtonTooltip,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDelete,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(color: WizColors.inkOverlay, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const Icon(Icons.close_rounded, size: 13, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diagonal 135° stripes (`#EEE8F6` / `#F7F3FB`, 8px) — placeholder for text-only deals.
class StripePlaceholder extends StatelessWidget {
  const StripePlaceholder({
    super.key,
    this.colorA = const Color(0xFFEEE8F6),
    this.colorB = const Color(0xFFF7F3FB),
    this.stripe = 8,
  });

  final Color colorA;
  final Color colorB;
  final double stripe;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _StripePainter(colorA, colorB, stripe), child: const SizedBox.expand());
}

class _StripePainter extends CustomPainter {
  const _StripePainter(this.a, this.b, this.stripe);

  final Color a;
  final Color b;
  final double stripe;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = b);
    final paint = Paint()
      ..color = a
      ..strokeWidth = stripe;
    // CSS 135deg: stripes run from top-left to bottom-right (perpendicular gradient).
    final period = stripe * 2 * 1.41421356;
    final extent = size.width + size.height;
    for (var d = -size.height; d < extent; d += period) {
      canvas.drawLine(Offset(d, 0), Offset(d - size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) => old.a != a || old.b != b || old.stripe != stripe;
}
