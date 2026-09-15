import 'dart:io';
import 'dart:math' as math;

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/scanning_overlay.dart';
import 'package:appwizard/features/pro_deal_closer/presentation/widgets/pro_message_tile.dart';
import 'package:flutter/material.dart';

/// User attachment bubble: ink container (padding 6, gap 6, radius 18/18/6/18)
/// with numbered 96×128 tiles (single: 150×200), a "+N" tile past three, a scan
/// line while uploading and the right-aligned reading label underneath.
class ProAttachmentBubble extends StatelessWidget {
  const ProAttachmentBubble({
    super.key,
    required this.paths,
    required this.isUploading,
    required this.readingLabel,
  });

  static const int maxTiles = 3;
  static const double _gap = 6;
  static const double _padding = 6;

  final List<String> paths;
  final bool isUploading;
  final String readingLabel;

  @override
  Widget build(BuildContext context) {
    final single = paths.length == 1;
    final shown = paths.take(maxTiles).toList();
    final more = paths.length - shown.length;
    final tileCount = shown.length + (more > 0 ? 1 : 0);
    final baseWidth = single ? 150.0 : 96.0;
    final baseHeight = single ? 200.0 : 128.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Shrink tiles when 3 + "+N" would not fit the bubble's max width.
            var tileWidth = baseWidth;
            if (constraints.hasBoundedWidth) {
              final available = constraints.maxWidth - 2 * _padding - _gap * (tileCount - 1);
              tileWidth = math.max(48, math.min(baseWidth, available / tileCount));
            }
            final tileHeight = baseHeight * (tileWidth / baseWidth);
            return Container(
              padding: const EdgeInsets.all(_padding),
              decoration: const BoxDecoration(
                color: WizColors.ink,
                borderRadius: kProUserRadius,
                boxShadow: [
                  BoxShadow(color: Color(0x1A463270), blurRadius: 14, offset: Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < shown.length; i++) ...[
                    if (i > 0) const SizedBox(width: _gap),
                    _ShotTile(
                      path: shown[i],
                      number: i + 1,
                      width: tileWidth,
                      height: tileHeight,
                      isUploading: isUploading,
                    ),
                  ],
                  if (more > 0) ...[
                    const SizedBox(width: _gap),
                    _MoreTile(label: '+$more', width: tileWidth, height: tileHeight),
                  ],
                ],
              ),
            );
          },
        ),
        if (isUploading)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              readingLabel,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: WizType.bodyFont,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: WizColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

class _ShotTile extends StatelessWidget {
  const _ShotTile({
    required this.path,
    required this.number,
    required this.width,
    required this.height,
    required this.isUploading,
  });

  final String path;
  final int number;
  final double width;
  final double height;
  final bool isUploading;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            ImageWithScanningOverlay(
              width: width,
              height: height,
              borderRadius: 12,
              isUploading: isUploading,
              child: Image.file(
                File(path),
                width: width,
                height: height,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: width,
                  height: height,
                  color: WizColors.surfaceMuted,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    size: 20,
                    color: WizColors.textTertiary,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 5,
              left: 5,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(color: WizColors.ink, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  '$number',
                  style: const TextStyle(
                    fontFamily: WizType.bodyFont,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.label, required this.width, required this.height});

  final String label;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0x1FFFFFFF),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: WizType.display,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
}
