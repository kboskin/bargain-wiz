import 'package:flutter/material.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';

/// 48h home app bar: ☰ (44px hit) · "Bargain Wiz" Outfit 17/600 · ink Share pill (36h, radius 18).
class HomeAppBar extends StatelessWidget {
  const HomeAppBar({
    super.key,
    required this.title,
    required this.shareLabel,
    required this.onMenu,
    required this.onShare,
  });

  final String title;
  final String shareLabel;
  final VoidCallback onMenu;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: MaterialLocalizations.of(context).openAppDrawerTooltip,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onMenu,
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(child: Icon(Icons.menu_rounded, size: 22, color: WizColors.ink)),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WizType.appBarTitle,
                ),
              ),
              SharePill(label: shareLabel, onTap: onShare),
            ],
          ),
        ),
      );
}

/// Ink pill 36h radius 18 with a share glyph and Figtree 13/600 label.
class SharePill extends StatelessWidget {
  const SharePill({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => WizPressable(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
          decoration: BoxDecoration(
            color: WizColors.ink,
            borderRadius: BorderRadius.circular(WizRadii.pillXs),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.ios_share_rounded, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(label, style: WizType.captionStrong.copyWith(color: Colors.white, height: 1)),
            ],
          ),
        ),
      );
}
