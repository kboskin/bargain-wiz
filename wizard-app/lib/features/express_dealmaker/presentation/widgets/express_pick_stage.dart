import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/wiz/fade_up.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/features/express_dealmaker/presentation/express_copy.dart';
import 'package:appwizard/features/express_dealmaker/presentation/pages/screenshot_upload_item.dart';
import 'package:appwizard/features/express_dealmaker/presentation/widgets/dashed_border.dart';
import 'package:appwizard/features/express_dealmaker/presentation/widgets/screenshot_tile.dart';

/// 5a Pick: title + description, dashed drop zone (no selection) or a wrap of
/// 104×139 tiles (more than [maxVisibleTiles] collapse into "+N"), CTA
/// "✨ Read N screenshots" disabled at 0.
class ExpressPickStage extends StatelessWidget {
  const ExpressPickStage({
    required this.items,
    required this.copy,
    required this.onPick,
    required this.onRemove,
    required this.onStart,
    super.key,
  });

  static const int maxVisibleTiles = 5;
  static const double tileWidth = 104;
  static const double tileHeight = 139;

  final List<ScreenshotUploadItem> items;
  final ExpressCopy copy;
  final VoidCallback onPick;
  final ValueChanged<int> onRemove;
  final VoidCallback onStart;

  @override
  Widget build(final BuildContext context) {
    final bottom = math.max(MediaQuery.paddingOf(context).bottom, 20.0);
    return Padding(
      padding: EdgeInsets.fromLTRB(WizSpacing.gutter, 8, WizSpacing.gutter, bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(copy.pickTitle, style: WizType.titleSm),
          const SizedBox(height: 4),
          Text(copy.pickDescription, style: WizType.bodySm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: WizSpacing.section),
              child: items.isEmpty ? _buildDropZone() : _buildTiles(context),
            ),
          ),
          WizPrimaryButton(
            label: '✨ ${copy.pickCta(items.length)}',
            onPressed: items.isEmpty ? null : onStart,
          ),
        ],
      ),
    );
  }

  Widget _buildDropZone() => WizPressable(
        onTap: onPick,
        scale: 0.99,
        child: DashedBorder(
          fill: const Color(0x73FFFFFF), // white 45%
          child: Container(
            constraints: const BoxConstraints(minHeight: 200),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(color: WizColors.ink, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Icon(Icons.photo_camera_outlined, size: 26, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  copy.dropzone,
                  textAlign: TextAlign.center,
                  style: WizType.bodyMd.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Text(
                  copy.dropzoneSub,
                  textAlign: TextAlign.center,
                  style: WizType.caption.copyWith(color: WizColors.textTertiary),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildTiles(final BuildContext context) {
    final visible = items.length > maxVisibleTiles ? items.take(maxVisibleTiles).toList() : items;
    final hidden = items.length - visible.length;
    return SingleChildScrollView(
      child: Wrap(
        spacing: WizSpacing.stack,
        runSpacing: WizSpacing.stack,
        children: [
          for (var i = 0; i < visible.length; i++)
            FadeUp(
              key: ValueKey('pick-${visible[i].path}'),
              duration: const Duration(milliseconds: 300),
              child: ScreenshotTile(
                path: visible[i].path,
                number: i + 1,
                width: tileWidth,
                height: tileHeight,
                onRemove: () => onRemove(i),
              ),
            ),
          if (hidden > 0)
            MoreTile(
              count: hidden,
              width: tileWidth,
              height: tileHeight,
              subLabel: 'more',
              onTap: onPick,
            ),
          AddTile(
            width: tileWidth,
            height: tileHeight,
            onTap: onPick,
            semanticLabel: copy.addScreenshot,
          ),
        ],
      ),
    );
  }
}
