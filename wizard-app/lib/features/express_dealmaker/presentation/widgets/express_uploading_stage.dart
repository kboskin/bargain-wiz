import 'package:flutter/material.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/features/express_dealmaker/presentation/express_copy.dart';
import 'package:appwizard/features/express_dealmaker/presentation/pages/screenshot_upload_item.dart';
import 'package:appwizard/features/express_dealmaker/presentation/widgets/screenshot_tile.dart';

/// 5b Uploading: 1–2 shots → row of 140×187 cards; ≥3 → 3-col grid of 104×139.
/// Each card shows a number badge and the teal scan line; failed uploads get a
/// per-card Retry chip. Below: purple spinner + "Reading the listing…".
class ExpressUploadingStage extends StatelessWidget {
  const ExpressUploadingStage({
    required this.items,
    required this.copy,
    required this.onRetry,
    super.key,
  });

  final List<ScreenshotUploadItem> items;
  final ExpressCopy copy;
  final ValueChanged<int> onRetry;

  static const List<BoxShadow> _shadow = [
    BoxShadow(color: Color(0x24463270), blurRadius: 30, offset: Offset(0, 10)),
  ];

  @override
  Widget build(final BuildContext context) {
    final big = items.length <= 2;
    final w = big ? 140.0 : 104.0;
    final h = big ? 187.0 : 139.0;
    final gap = big ? WizSpacing.stackLg : WizSpacing.stack;

    final cards = [
      for (var i = 0; i < items.length; i++)
        ScreenshotTile(
          key: ValueKey('upload-${items[i].path}'),
          path: items[i].path,
          number: i + 1,
          width: w,
          height: h,
          radius: WizRadii.thumbXl,
          badgeSize: 22,
          badgeInset: 8,
          scanning: !items[i].isFailed,
          failed: items[i].isFailed,
          retryLabel: copy.retry,
          onRetry: () => onRetry(i),
          shadow: _shadow,
        ),
    ];

    final Widget grid = big
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                cards[i],
              ],
            ],
          )
        : SizedBox(
            width: w * 3 + gap * 2,
            child: Wrap(spacing: gap, runSpacing: gap, children: cards),
          );

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: WizSpacing.gutter, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            grid,
            const SizedBox(height: 22),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: WizColors.purple),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    copy.uploadingStatus,
                    textAlign: TextAlign.center,
                    style: WizType.statusSm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
