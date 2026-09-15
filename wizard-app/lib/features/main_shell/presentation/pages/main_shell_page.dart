import 'package:flutter/material.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/features/history/presentation/pages/history_page.dart';
import 'package:appwizard/features/home/presentation/pages/home_tab.dart';
import 'package:appwizard/features/home/presentation/widgets/home_drawer.dart';
import 'package:appwizard/features/lines_that_land/presentation/pages/lines_tab_page.dart';
import 'package:appwizard/features/main_shell/domain/main_tab.dart';
import 'package:appwizard/features/main_shell/domain/main_tab_spec.dart';
import 'package:appwizard/features/main_shell/presentation/main_shell_controller.dart';
import 'package:appwizard/features/main_shell/presentation/widgets/wiz_tab_bar.dart';
import 'package:appwizard/features/profile/presentation/pages/profile_page.dart';

export 'package:appwizard/features/main_shell/domain/main_tab.dart';
export 'package:appwizard/features/main_shell/presentation/main_shell_controller.dart';

/// Main tab shell: Home · Lines · History · Profile with the frosted tab bar and the
/// legacy drawer. Transparent over the app gradient ([PastelGradientBackground] wraps the app).
///
/// Tab order and labels come from `main_page_config.tabs`; tab bodies read
/// [MainShellScope.of(context)] to switch tabs or open the drawer.
class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key, this.initialTab = MainTab.home});

  final MainTab initialTab;

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  late final MainShellController _controller = MainShellController(initialTab: widget.initialTab);
  late List<MainTabSpec> _tabs;

  @override
  void initState() {
    super.initState();
    final configured = di.sl<RemoteConfigService>().getMainPageConfig()?.tabs;
    _tabs = MainTabSpec.resolve(configured?.map((t) => (id: t.id, label: t.label)));
    // Deep link to a tab that is not in the bar → fall back to the first one.
    if (!_tabs.any((t) => t.tab == widget.initialTab)) {
      _controller.select(_tabs.first.tab);
    }
  }

  @override
  void didUpdateWidget(covariant MainShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) _controller.select(widget.initialTab);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _body(MainTab tab) {
    switch (tab) {
      case MainTab.home:
        return const HomeTab();
      case MainTab.lines:
        return const LinesTabPage();
      case MainTab.history:
        return const HistoryPage();
      case MainTab.profile:
        return const ProfilePage();
    }
  }

  @override
  Widget build(BuildContext context) => MainShellScope(
        controller: _controller,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final selected = _controller.tab;
            final index = _tabs.indexWhere((t) => t.tab == selected).clamp(0, _tabs.length - 1);
            return Scaffold(
              key: _controller.scaffoldKey,
              backgroundColor: Colors.transparent,
              drawerScrimColor: WizColors.scrim,
              drawerEdgeDragWidth: 28,
              drawer: const HomeDrawer(),
              body: Stack(
                children: [
                  Positioned.fill(
                    child: IndexedStack(
                      index: index,
                      children: [for (final t in _tabs) _body(t.tab)],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: WizTabBar(
                      items: _tabs,
                      selected: selected,
                      onSelected: _controller.select,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
}
