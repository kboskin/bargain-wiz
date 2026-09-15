import 'dart:io';

import 'package:flutter/material.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/scanning_overlay.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/features/express_dealmaker/presentation/widgets/dashed_border.dart';

/// Screenshot thumbnail with an ink number badge, optional ✕ (remove), teal
/// scan line (uploading) and a black54 Retry chip (failed upload).
class ScreenshotTile extends StatelessWidget {
  const ScreenshotTile({
    required this.path,
    required this.number,
    required this.width,
    required this.height,
    super.key,
    this.radius = WizRadii.thumbLg,
    this.badgeSize = 20,
    this.badgeInset = 6,
    this.scanning = false,
    this.failed = false,
    this.onRemove,
    this.onRetry,
    this.onTap,
    this.retryLabel,
    this.shadow = WizShadows.screenshot,
  });

  final String path;
  final int number;
  final double width;
  final double height;
  final double radius;
  final double badgeSize;
  final double badgeInset;
  final bool scanning;
  final bool failed;
  final VoidCallback? onRemove;
  final VoidCallback? onRetry;
  final VoidCallback? onTap;
  /// Text next to the refresh icon on the Retry chip; icon-only when null.
  final String? retryLabel;
  final List<BoxShadow>? shadow;

  @override
  Widget build(final BuildContext context) {
    final badgeFont = (badgeSize * 0.55).roundToDouble();
    Widget tile = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (final _, final __, final ___) => const ColoredBox(
                color: WizColors.surfaceMuted,
                child: Icon(Icons.image_outlined, color: WizColors.textTertiary),
              ),
            ),
            if (scanning)
              ScanningOverlay(width: width, height: height, borderRadius: radius),
            Positioned(
              top: badgeInset,
              left: badgeInset,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: const BoxDecoration(color: WizColors.ink, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  '$number',
                  style: TextStyle(
                    fontFamily: WizType.bodyFont,
                    fontSize: badgeFont,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
            ),
            if (onRemove != null)
              Positioned(
                top: badgeInset,
                right: badgeInset,
                child: GestureDetector(
                  onTap: onRemove,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: badgeSize,
                    height: badgeSize,
                    decoration: const BoxDecoration(
                      color: WizColors.inkOverlay,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.close_rounded, size: badgeSize * 0.65, color: Colors.white),
                  ),
                ),
              ),
            if (failed && onRetry != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 6,
                child: Center(
                  child: _RetryChip(label: retryLabel, onTap: onRetry!),
                ),
              ),
          ],
        ),
      ),
    );
    if (onTap != null) {
      tile = WizPressable(onTap: onTap, scale: 0.97, child: tile);
    }
    return tile;
  }
}

class _RetryChip extends StatelessWidget {
  const _RetryChip({required this.onTap, this.label});

  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(final BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: label == null
              ? const EdgeInsets.all(5)
              : const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(WizRadii.chip),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.refresh_rounded, size: 14, color: Colors.white),
              if (label != null) ...[
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: WizType.chipSm.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

/// Ink "+N" tile (collapsed extra screenshots). Tap opens the picker.
class MoreTile extends StatelessWidget {
  const MoreTile({
    required this.count,
    required this.width,
    required this.height,
    super.key,
    this.radius = WizRadii.thumbLg,
    this.fontSize = 20,
    this.subLabel,
    this.onTap,
  });

  final int count;
  final double width;
  final double height;
  final double radius;
  final double fontSize;
  /// Small caption under the count (e.g. "more"); omitted when null.
  final String? subLabel;
  final VoidCallback? onTap;

  @override
  Widget build(final BuildContext context) => WizPressable(
        onTap: onTap,
        scale: 0.97,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: WizColors.ink,
            borderRadius: BorderRadius.circular(radius),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '+$count',
                style: TextStyle(
                  fontFamily: WizType.display,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              if (subLabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  subLabel!,
                  style: const TextStyle(
                    fontFamily: WizType.bodyFont,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: WizColors.borderStrong,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

/// Dashed "+ Add" tile. Tap opens the picker.
class AddTile extends StatelessWidget {
  const AddTile({
    required this.width,
    required this.height,
    required this.onTap,
    super.key,
    this.radius = WizRadii.thumbLg,
    this.iconSize = 24,
    this.semanticLabel,
  });

  final double width;
  final double height;
  final VoidCallback onTap;
  final double radius;
  final double iconSize;
  final String? semanticLabel;

  @override
  Widget build(final BuildContext context) => Semantics(
        button: true,
        label: semanticLabel,
        child: WizPressable(
          onTap: onTap,
          scale: 0.97,
          child: SizedBox(
            width: width,
            height: height,
            child: DashedBorder(
              strokeWidth: 1.5,
              radius: radius,
              dash: 6,
              gap: 5,
              child: Center(
                child: Icon(Icons.add_rounded, size: iconSize, color: WizColors.textSecondary),
              ),
            ),
          ),
        ),
      );
}
