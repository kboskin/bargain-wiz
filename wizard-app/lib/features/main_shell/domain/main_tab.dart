/// Bottom tab bar items of the main shell. Ids match `main_page_config.tabs[].id`.
enum MainTab {
  home,
  lines,
  history,
  profile;

  static MainTab fromId(String? id, {MainTab fallback = MainTab.home}) =>
      MainTab.values.where((t) => t.name == id).firstOrNull ?? fallback;
}
