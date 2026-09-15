import 'package:flutter/material.dart';

import 'package:appwizard/features/main_shell/domain/main_tab.dart';

/// Tab + drawer state of the main shell.
///
/// Tabs read it through [MainShellScope.of] to switch tabs ("See all" → History)
/// or open the drawer (☰ on the Home app bar).
class MainShellController extends ChangeNotifier {
  MainShellController({MainTab initialTab = MainTab.home}) : _tab = initialTab;

  /// Key of the shell [Scaffold]; used to open/close the drawer.
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  MainTab _tab;
  MainTab get tab => _tab;

  /// Switches the visible tab (no-op when already selected).
  void select(MainTab tab) {
    if (_tab == tab) return;
    _tab = tab;
    notifyListeners();
  }

  void openDrawer() => scaffoldKey.currentState?.openDrawer();

  void closeDrawer() {
    final s = scaffoldKey.currentState;
    if (s != null && s.isDrawerOpen) s.closeDrawer();
  }
}

/// Exposes the [MainShellController] to the tab bodies.
class MainShellScope extends InheritedNotifier<MainShellController> {
  const MainShellScope({super.key, required MainShellController controller, required super.child})
      : super(notifier: controller);

  /// Rebuilds on tab changes.
  static MainShellController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MainShellScope>();
    assert(scope != null, 'MainShellScope not found above this widget');
    return scope!.notifier!;
  }

  /// Null when the widget is rendered outside the shell (e.g. as a plain route).
  static MainShellController? maybeOf(BuildContext context, {bool listen = true}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<MainShellScope>()
        : context.getInheritedWidgetOfExactType<MainShellScope>();
    return scope?.notifier;
  }
}
