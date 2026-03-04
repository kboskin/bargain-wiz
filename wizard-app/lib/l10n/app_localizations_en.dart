// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Bargain Wiz';

  @override
  String get welcome => 'Welcome';

  @override
  String get goBack => 'Go Back';

  @override
  String get skip => 'Skip';

  @override
  String get next => 'Next';

  @override
  String get getStarted => 'Get Started';

  @override
  String get pleaseSelectOption => 'Please select an option';

  @override
  String get pleaseSelectValue => 'Please select a value';

  @override
  String get invalidScreenIndex => 'Invalid screen index';

  @override
  String get noOnboardingConfig => 'No onboarding configuration available';

  @override
  String get termsAndConditions => 'Terms and Conditions';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String agreeToTerms(String appName) {
    return 'By continuing, you agree to $appName\'s';
  }

  @override
  String get and => ' and ';

  @override
  String get error => 'Error';

  @override
  String get loading => 'Loading...';

  @override
  String get signIn => 'Sign in';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get signInWithApple => 'Sign in with Apple';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get continueButton => 'Continue';

  @override
  String get restorePurchases => 'Restore Purchases';

  @override
  String get terms => 'Terms';

  @override
  String get privacy => 'Privacy';

  @override
  String get productNotAvailable => 'Product not available. Please try again.';

  @override
  String get subscriptionActivated => 'Subscription activated!';

  @override
  String get skipForNow => 'Skip for now';

  @override
  String get homeEmptyTitle => 'Your deal, upgraded.';

  @override
  String get homeModeChooserTitle => 'Choose your magic';

  @override
  String get simpleModeTitle => 'Express Dealmaker';

  @override
  String get simpleModeSubtitle =>
      'Drop a screenshot, get deal lines from the AI';

  @override
  String get chatModeTitle => 'Pro Deal Closer';

  @override
  String get chatModeSubtitle => 'Chat with the wizard';

  @override
  String get simpleModeDropHint => 'Drop a screenshot';

  @override
  String get simpleModeAddScreenshot => 'Add screenshot';

  @override
  String get tapReplyToCopy => 'tap a reply to copy';

  @override
  String get simpleModeSeeing => 'Seeing';

  @override
  String get getDealReply => 'Get deal reply';

  @override
  String get expressDealmakerKeywordHint => 'Give us a word or two to focus on';

  @override
  String get expressDealmakerKeywordHintShort => 'Optional keywords';

  @override
  String get holdReplyForMore => 'hold a reply for more';

  @override
  String get getMore => 'Get More';

  @override
  String get retry => 'Retry';

  @override
  String get linesSectionTitle => 'Conversation starters & negotiation ideas';

  @override
  String get linesSectionSubtitle => 'Tap a line to copy and use in your chat';

  @override
  String get linesPlaceholder =>
      'Get lines to start conversations and negotiation ideas';

  @override
  String get uploadScreenshot => 'Express Dealmaker';

  @override
  String get enterTextManually => 'Pro Deal Closer';

  @override
  String get getPickupLines => 'Lines that land';

  @override
  String get startNewNegotiation => 'Start new negotiation';

  @override
  String get share => 'Share';

  @override
  String get profile => 'Profile';

  @override
  String get bargainsHistory => 'Bargains History';

  @override
  String get logOut => 'Log out';

  @override
  String get signInError => 'Uh, something went wrong. Please try again.';
}
