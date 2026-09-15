/// App routes configuration
class AppRoutes {
  /// Entry: decides between Welcome (first run) and the main tab shell.
  static const String home = '/';
  static const String onboarding = '/onboarding';
  /// Full-screen modal. Pass [PaywallArgs] as `extra`; pops `true` when access was granted.
  static const String paywall = '/paywall';
  /// Main tab shell (Home · Lines · History · Profile).
  static const String main = '/main';
  /// Tab deep links (open the shell on a given tab).
  static const String lines = '/lines';
  static const String history = '/history';
  static const String profile = '/profile';
  /// Express Dealmaker (screenshot → lines). `extra`: [ExpressDealmakerArgs]?
  static const String express = '/express';
  /// Pro Deal Closer chat. `extra`: [ProDealCloserArgs]?
  static const String pro = '/pro';
  /// Legacy alias for [pro].
  static const String startWithText = '/start-with-text';
  static const String feedback = '/feedback';

  static const String homeName = 'home';
  static const String onboardingName = 'onboarding';
  static const String paywallName = 'paywall';
  static const String mainName = 'main';
  static const String linesName = 'lines';
  static const String historyName = 'history';
  static const String profileName = 'profile';
  static const String expressName = 'express';
  static const String proName = 'pro';
  static const String startWithTextName = 'startWithText';
  static const String feedbackName = 'feedback';
}
