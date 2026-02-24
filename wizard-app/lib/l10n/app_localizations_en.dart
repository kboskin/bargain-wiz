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
  String get homeEmptyTitle => 'Upload a screenshot of a chat or bio';

  @override
  String get uploadScreenshot => 'Upload a Screenshot';

  @override
  String get enterTextManually => 'Enter Text Manually';

  @override
  String get getPickupLines => 'Get Pickup Lines';

  @override
  String get startNewNegotiation => 'Start new negotiation';

  @override
  String get profile => 'Profile';

  @override
  String get bargainsHistory => 'Bargains History';
}
