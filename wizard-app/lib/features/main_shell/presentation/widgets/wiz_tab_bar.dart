import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/template_text.dart';
import 'package:appwizard/features/main_shell/domain/main_tab.dart';
import 'package:appwizard/features/main_shell/domain/main_tab_spec.dart';

/// Frosted bottom tab bar (84h incl. home indicator): white 80% + blur 20,
/// top border white 95%, 4 items min-width 64, icon in a 36×24 pill, Figtree 11/600 label.
class WizTabBar extends StatelessWidget {
  const WizTabBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<MainTabSpec> items;
  final MainTab selected;
  final ValueChanged<MainTab> onSelected;

  /// Height of the bar above the home indicator area.
  static const double contentHeight = WizSpacing.tabBarHeight - _bottomPadding;
  static const double _bottomPadding = 30;

  /// Total bar height on this device (84 on the design canvas; grows with a taller inset).
  static double heightFor(BuildContext context) =>
      contentHeight + math.max(_bottomPadding, MediaQuery.viewPaddingOf(context).bottom);

  /// Bottom padding tab bodies should leave so scrolling content clears the bar (100 on the canvas).
  static double contentPaddingFor(BuildContext context) =>
      heightFor(context) + (WizSpacing.tabBarContentPadding - WizSpacing.tabBarHeight);

  static IconData iconFor(MainTab tab) {
    switch (tab) {
      case MainTab.home:
        return Icons.home_rounded;
      case MainTab.lines:
        return Icons.auto_awesome;
      case MainTab.history:
        return Icons.view_agenda_outlined;
      case MainTab.profile:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    final bottom = math.max(_bottomPadding, inset);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: contentHeight + bottom,
          padding: EdgeInsets.fromLTRB(12, 8, 12, bottom),
          decoration: const BoxDecoration(
            color: WizColors.frostedBar,
            border: Border(top: BorderSide(color: WizColors.frostedBorder)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final item in items)
                _TabItem(
                  spec: item,
                  active: item.tab == selected,
                  onTap: () => onSelected(item.tab),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.spec, required this.active, required this.onTap});

  final MainTabSpec spec;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? WizColors.ink : WizColors.textTertiary;
    final label = TemplateText.textOf(context, spec.label, fallback: spec.fallbackLabel);
    return Semantics(
      selected: active,
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: WizMotion.scrim,
                  width: 36,
                  height: 24,
                  decoration: BoxDecoration(
                    color: active ? WizColors.tabActivePill : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(WizTabBar.iconFor(spec.tab), size: 18, color: color),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WizType.tabLabel.copyWith(color: color, height: 1.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
