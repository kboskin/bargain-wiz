import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'Bargain Wiz'**
  String get appTitle;

  /// Welcome message
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// Button text to go back
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// Button text to skip onboarding
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// Button text to go to next screen
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Button text to complete onboarding
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// Validation message when option not selected
  ///
  /// In en, this message translates to:
  /// **'Please select an option'**
  String get pleaseSelectOption;

  /// Validation message when value not selected
  ///
  /// In en, this message translates to:
  /// **'Please select a value'**
  String get pleaseSelectValue;

  /// Error message for invalid screen index
  ///
  /// In en, this message translates to:
  /// **'Invalid screen index'**
  String get invalidScreenIndex;

  /// Message when onboarding config is not available
  ///
  /// In en, this message translates to:
  /// **'No onboarding configuration available'**
  String get noOnboardingConfig;

  /// Terms and conditions link text
  ///
  /// In en, this message translates to:
  /// **'Terms and Conditions'**
  String get termsAndConditions;

  /// Privacy policy link text
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Terms agreement text
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to {appName}\'s'**
  String agreeToTerms(String appName);

  /// Conjunction word
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get and;

  /// Generic error label
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Loading indicator text
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Sign in button/label
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// Sign in with Google button text
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// Sign in with Apple button text
  ///
  /// In en, this message translates to:
  /// **'Sign in with Apple'**
  String get signInWithApple;

  /// Text before sign up link
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// Text before sign in link
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// Continue button text
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// Restore purchases button text
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get restorePurchases;

  /// Terms link text
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get terms;

  /// Privacy link text
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// Error message when subscription product is not available
  ///
  /// In en, this message translates to:
  /// **'Product not available. Please try again.'**
  String get productNotAvailable;

  /// Success message when subscription is activated
  ///
  /// In en, this message translates to:
  /// **'Subscription activated!'**
  String get subscriptionActivated;

  /// Button text to skip paywall temporarily
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNow;

  /// Main empty state title – confident, outcome-focused
  ///
  /// In en, this message translates to:
  /// **'Your deal, upgraded.'**
  String get homeEmptyTitle;

  /// Title above Simple vs Chat mode choice
  ///
  /// In en, this message translates to:
  /// **'Choose your magic'**
  String get homeModeChooserTitle;

  /// Simple mode: drop screenshot, get AI replies
  ///
  /// In en, this message translates to:
  /// **'Express Dealmaker'**
  String get simpleModeTitle;

  /// Subtitle for simple mode card
  ///
  /// In en, this message translates to:
  /// **'Drop a screenshot, get deal lines from the AI'**
  String get simpleModeSubtitle;

  /// Chat mode: conversation with wizard
  ///
  /// In en, this message translates to:
  /// **'Pro Deal Closer'**
  String get chatModeTitle;

  /// Subtitle for chat mode card
  ///
  /// In en, this message translates to:
  /// **'Chat with the wizard'**
  String get chatModeSubtitle;

  /// Hint in simple mode when no screenshots
  ///
  /// In en, this message translates to:
  /// **'Drop a screenshot'**
  String get simpleModeDropHint;

  /// Button to add another screenshot
  ///
  /// In en, this message translates to:
  /// **'Add screenshot'**
  String get simpleModeAddScreenshot;

  /// Hint below AI replies
  ///
  /// In en, this message translates to:
  /// **'tap a reply to copy'**
  String get tapReplyToCopy;

  /// AI observation card title
  ///
  /// In en, this message translates to:
  /// **'Seeing'**
  String get simpleModeSeeing;

  /// Button to get AI reply
  ///
  /// In en, this message translates to:
  /// **'Get deal reply'**
  String get getDealReply;

  /// Placeholder for keyword input in Express Dealmaker (shown above reply card)
  ///
  /// In en, this message translates to:
  /// **'Give us a word or two to focus on'**
  String get expressDealmakerKeywordHint;

  /// Short placeholder for keyword field in assist panel
  ///
  /// In en, this message translates to:
  /// **'Optional keywords'**
  String get expressDealmakerKeywordHintShort;

  /// Hint that holding a reply shows more options
  ///
  /// In en, this message translates to:
  /// **'hold a reply for more'**
  String get holdReplyForMore;

  /// Button to generate more AI replies
  ///
  /// In en, this message translates to:
  /// **'Get More'**
  String get getMore;

  /// Retry button for failed upload
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Section title for deal lines / reply options
  ///
  /// In en, this message translates to:
  /// **'Conversation starters & negotiation ideas'**
  String get linesSectionTitle;

  /// Hint below the lines section title
  ///
  /// In en, this message translates to:
  /// **'Tap a line to copy and use in your chat'**
  String get linesSectionSubtitle;

  /// Placeholder when no lines have been generated yet
  ///
  /// In en, this message translates to:
  /// **'Get lines to start conversations and negotiation ideas'**
  String get linesPlaceholder;

  /// Primary CTA – screenshot/scan mode
  ///
  /// In en, this message translates to:
  /// **'Express Dealmaker'**
  String get uploadScreenshot;

  /// Chat mode button
  ///
  /// In en, this message translates to:
  /// **'Pro Deal Closer'**
  String get enterTextManually;

  /// Deal lines – punchy, implies success
  ///
  /// In en, this message translates to:
  /// **'Lines that land'**
  String get getPickupLines;

  /// App bar action for new negotiation
  ///
  /// In en, this message translates to:
  /// **'Start new negotiation'**
  String get startNewNegotiation;

  /// App bar share button label
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// Drawer item label
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Drawer item label
  ///
  /// In en, this message translates to:
  /// **'Bargains History'**
  String get bargainsHistory;

  /// Drawer logout button when user is signed in
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// Drawer item to open rate/satisfaction flow
  ///
  /// In en, this message translates to:
  /// **'Rate Us'**
  String get rateUs;

  /// Rate Us dialog title
  ///
  /// In en, this message translates to:
  /// **'Are you satisfied?'**
  String get areYouSatisfied;

  /// Yes button
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No button
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// Message shown when Google or Apple sign-in fails
  ///
  /// In en, this message translates to:
  /// **'Uh, something went wrong. Please try again.'**
  String get signInError;

  /// Drawer and button label for referral / invite friends
  ///
  /// In en, this message translates to:
  /// **'Refer'**
  String get refer;

  /// Title of the referral benefits bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Invite friends & earn'**
  String get referModalTitle;

  /// First referral benefit bullet
  ///
  /// In en, this message translates to:
  /// **'Give friends access to Bargain Wiz – smarter deals and negotiation help.'**
  String get referBenefit1;

  /// Second referral benefit bullet
  ///
  /// In en, this message translates to:
  /// **'You earn rewards when friends join using your invite link.'**
  String get referBenefit2;

  /// Third referral benefit bullet
  ///
  /// In en, this message translates to:
  /// **'The more you share, the more you can earn.'**
  String get referBenefit3;

  /// CTA button to share referral / invite link
  ///
  /// In en, this message translates to:
  /// **'Share invite link'**
  String get referShareInvite;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
