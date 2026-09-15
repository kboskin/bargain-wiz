import 'package:appwizard/features/main_shell/domain/main_tab.dart';

/// Raw bottom-bar item as it comes from `main_page_config.tabs[]` (id + remote label).
/// A record so this domain helper (and its tests) stay free of the remote-config models.
typedef MainTabInput = ({String id, dynamic label});

/// One resolved bottom-bar item: which [MainTab] it is plus its remote label
/// (a `MultilocaleText` / `String`, resolved with `TemplateText.textOf`).
class MainTabSpec {
  const MainTabSpec({required this.tab, this.label});

  final MainTab tab;

  /// Remote label (may be null → use [fallbackLabel]).
  final dynamic label;

  /// English fallback used when the remote label is missing.
  String get fallbackLabel => defaultLabels[tab]!;

  static const Map<MainTab, String> defaultLabels = {
    MainTab.home: 'Home',
    MainTab.lines: 'Lines',
    MainTab.history: 'History',
    MainTab.profile: 'Profile',
  };

  /// Default order: Home · Lines · History · Profile.
  static List<MainTabSpec> get defaults =>
      MainTab.values.map((t) => MainTabSpec(tab: t)).toList(growable: false);

  /// Resolves the bar items from `main_page_config.tabs`.
  ///
  /// Unknown ids are dropped, duplicates keep their first occurrence, and when
  /// the config is missing / empty / contains no known ids the default order is used.
  static List<MainTabSpec> resolve(Iterable<MainTabInput>? tabs) {
    if (tabs == null || tabs.isEmpty) return defaults;
    final seen = <MainTab>{};
    final out = <MainTabSpec>[];
    for (final t in tabs) {
      final id = t.id.trim().toLowerCase();
      final tab = MainTab.values.where((v) => v.name == id).firstOrNull;
      if (tab == null || !seen.add(tab)) continue;
      out.add(MainTabSpec(tab: tab, label: t.label));
    }
    return out.isEmpty ? defaults : out;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MainTabSpec && other.tab == tab && other.label == label;

  @override
  int get hashCode => Object.hash(tab, label);

  @override
  String toString() => 'MainTabSpec(${tab.name}, $label)';
}
