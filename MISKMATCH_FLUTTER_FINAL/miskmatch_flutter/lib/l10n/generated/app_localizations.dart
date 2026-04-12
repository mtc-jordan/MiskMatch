import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
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
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S? of(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

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
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'MiskMatch'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Sealed with musk.'**
  String get appTagline;

  /// No description provided for @quranRef.
  ///
  /// In en, this message translates to:
  /// **'Quran 83:26'**
  String get quranRef;

  /// No description provided for @findYourOtherHalf.
  ///
  /// In en, this message translates to:
  /// **'Find your\nother half.'**
  String get findYourOtherHalf;

  /// No description provided for @islamicWayTagline.
  ///
  /// In en, this message translates to:
  /// **'The Islamic way — with your guardian\'s blessing.'**
  String get islamicWayTagline;

  /// No description provided for @enterYourNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter your number'**
  String get enterYourNumber;

  /// No description provided for @verificationCodeHint.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send a verification code via SMS'**
  String get verificationCodeHint;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'79 123 4567'**
  String get phoneHint;

  /// No description provided for @enterValidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get enterValidPhone;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordHint;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordMinLength;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @newAccount.
  ///
  /// In en, this message translates to:
  /// **'New account'**
  String get newAccount;

  /// No description provided for @byContAgreement.
  ///
  /// In en, this message translates to:
  /// **'By continuing you agree to our '**
  String get byContAgreement;

  /// No description provided for @terms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get terms;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @guardianInformed.
  ///
  /// In en, this message translates to:
  /// **'Your guardian will be kept informed'**
  String get guardianInformed;

  /// No description provided for @iAmA.
  ///
  /// In en, this message translates to:
  /// **'I am a'**
  String get iAmA;

  /// No description provided for @brother.
  ///
  /// In en, this message translates to:
  /// **'Brother'**
  String get brother;

  /// No description provided for @sister.
  ///
  /// In en, this message translates to:
  /// **'Sister'**
  String get sister;

  /// No description provided for @selectCountry.
  ///
  /// In en, this message translates to:
  /// **'Select country'**
  String get selectCountry;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @countryNameOrCode.
  ///
  /// In en, this message translates to:
  /// **'Country name or code'**
  String get countryNameOrCode;

  /// No description provided for @enterVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Enter verification code'**
  String get enterVerificationCode;

  /// No description provided for @otpSentHint.
  ///
  /// In en, this message translates to:
  /// **'6-digit code sent to your phone'**
  String get otpSentHint;

  /// No description provided for @verifyAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Verify & continue'**
  String get verifyAndContinue;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendCode;

  /// No description provided for @otpPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Your OTP is private. We will never ask for it.'**
  String get otpPrivacyNote;

  /// No description provided for @verifyYourNumber.
  ///
  /// In en, this message translates to:
  /// **'Verify your\nnumber'**
  String get verifyYourNumber;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @bismillahDua.
  ///
  /// In en, this message translates to:
  /// **'بِسْمِ اللَّهِ وَعَلَى سُنَّةِ رَسُولِ اللَّهِ'**
  String get bismillahDua;

  /// No description provided for @bismillahTranslation.
  ///
  /// In en, this message translates to:
  /// **'\"In the name of Allah, upon the Sunnah of His Messenger\"'**
  String get bismillahTranslation;

  /// No description provided for @setYourNiyyah.
  ///
  /// In en, this message translates to:
  /// **'Set your niyyah'**
  String get setYourNiyyah;

  /// No description provided for @niyyahDescription.
  ///
  /// In en, this message translates to:
  /// **'Your intention matters more than anything else in this journey. State it clearly, sincerely, and with taqwa — for Allah sees what the eyes cannot.'**
  String get niyyahDescription;

  /// No description provided for @niyyahMarriage.
  ///
  /// In en, this message translates to:
  /// **'I intend to marry for the sake of Allah'**
  String get niyyahMarriage;

  /// No description provided for @niyyahRighteous.
  ///
  /// In en, this message translates to:
  /// **'I intend to find a righteous spouse'**
  String get niyyahRighteous;

  /// No description provided for @niyyahDeen.
  ///
  /// In en, this message translates to:
  /// **'I intend to protect my deen through marriage'**
  String get niyyahDeen;

  /// No description provided for @writeOwnNiyyah.
  ///
  /// In en, this message translates to:
  /// **'Or write your own intention...'**
  String get writeOwnNiyyah;

  /// No description provided for @declareNiyyah.
  ///
  /// In en, this message translates to:
  /// **'I declare my niyyah'**
  String get declareNiyyah;

  /// No description provided for @setNiyyahLater.
  ///
  /// In en, this message translates to:
  /// **'I\'ll set this later'**
  String get setNiyyahLater;

  /// No description provided for @yourGuardian.
  ///
  /// In en, this message translates to:
  /// **'Your Guardian'**
  String get yourGuardian;

  /// No description provided for @noMarriageWithoutGuardian.
  ///
  /// In en, this message translates to:
  /// **'لَا نِكَاحَ إِلَّا بِوَلِيٍّ'**
  String get noMarriageWithoutGuardian;

  /// No description provided for @noMarriageTranslation.
  ///
  /// In en, this message translates to:
  /// **'\"No marriage without a guardian\"'**
  String get noMarriageTranslation;

  /// No description provided for @whoIsGuardian.
  ///
  /// In en, this message translates to:
  /// **'Who is your guardian?'**
  String get whoIsGuardian;

  /// No description provided for @selectRelationship.
  ///
  /// In en, this message translates to:
  /// **'Select the relationship type'**
  String get selectRelationship;

  /// No description provided for @enterTheirDetails.
  ///
  /// In en, this message translates to:
  /// **'Enter their details'**
  String get enterTheirDetails;

  /// No description provided for @smsInvitationHint.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send them an SMS invitation'**
  String get smsInvitationHint;

  /// No description provided for @guardianFullName.
  ///
  /// In en, this message translates to:
  /// **'Guardian\'s full name'**
  String get guardianFullName;

  /// No description provided for @guardianNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Ahmad Al-Rashidi'**
  String get guardianNameHint;

  /// No description provided for @pleaseEnterGuardianName.
  ///
  /// In en, this message translates to:
  /// **'Please enter the guardian\'s name'**
  String get pleaseEnterGuardianName;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @completeSetup.
  ///
  /// In en, this message translates to:
  /// **'Complete Setup'**
  String get completeSetup;

  /// No description provided for @skipGuardianSetup.
  ///
  /// In en, this message translates to:
  /// **'Skip — set up guardian later'**
  String get skipGuardianSetup;

  /// No description provided for @chooseInvolvement.
  ///
  /// In en, this message translates to:
  /// **'Choose their involvement'**
  String get chooseInvolvement;

  /// No description provided for @changeSettingsLater.
  ///
  /// In en, this message translates to:
  /// **'You can change these settings later'**
  String get changeSettingsLater;

  /// No description provided for @mustApproveMatches.
  ///
  /// In en, this message translates to:
  /// **'Must approve all matches'**
  String get mustApproveMatches;

  /// No description provided for @mustApproveDesc.
  ///
  /// In en, this message translates to:
  /// **'Required — your guardian approves each match'**
  String get mustApproveDesc;

  /// No description provided for @canReadConversations.
  ///
  /// In en, this message translates to:
  /// **'Can read conversations'**
  String get canReadConversations;

  /// No description provided for @canReadDesc.
  ///
  /// In en, this message translates to:
  /// **'Your guardian can view chat messages'**
  String get canReadDesc;

  /// No description provided for @receivesNotifications.
  ///
  /// In en, this message translates to:
  /// **'Receives notifications'**
  String get receivesNotifications;

  /// No description provided for @receivesNotifDesc.
  ///
  /// In en, this message translates to:
  /// **'Gets notified about new matches and activity'**
  String get receivesNotifDesc;

  /// No description provided for @canJoinCalls.
  ///
  /// In en, this message translates to:
  /// **'Can join chaperoned calls'**
  String get canJoinCalls;

  /// No description provided for @canJoinCallsDesc.
  ///
  /// In en, this message translates to:
  /// **'Can listen in on voice/video calls'**
  String get canJoinCallsDesc;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @updateProfilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Update profile photo'**
  String get updateProfilePhoto;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseFromGallery;

  /// No description provided for @photoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Photo updated successfully'**
  String get photoUpdated;

  /// No description provided for @photoUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload photo'**
  String get photoUploadFailed;

  /// No description provided for @profileStrength.
  ///
  /// In en, this message translates to:
  /// **'Profile strength'**
  String get profileStrength;

  /// No description provided for @myVoiceIntro.
  ///
  /// In en, this message translates to:
  /// **'My voice intro'**
  String get myVoiceIntro;

  /// No description provided for @islamicPractice.
  ///
  /// In en, this message translates to:
  /// **'Islamic Practice'**
  String get islamicPractice;

  /// No description provided for @lifeGoals.
  ///
  /// In en, this message translates to:
  /// **'Life Goals'**
  String get lifeGoals;

  /// No description provided for @aboutMe.
  ///
  /// In en, this message translates to:
  /// **'About me'**
  String get aboutMe;

  /// No description provided for @readMore.
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get readMore;

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get showLess;

  /// No description provided for @completeYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get completeYourProfile;

  /// No description provided for @completeProfileHint.
  ///
  /// In en, this message translates to:
  /// **'Tell potential matches about yourself.\nA complete profile gets 3x more interest.'**
  String get completeProfileHint;

  /// No description provided for @setUpMyProfile.
  ///
  /// In en, this message translates to:
  /// **'Set up my profile'**
  String get setUpMyProfile;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @basicInfo.
  ///
  /// In en, this message translates to:
  /// **'Basic Info'**
  String get basicInfo;

  /// No description provided for @islamicIdentity.
  ///
  /// In en, this message translates to:
  /// **'Islamic Identity'**
  String get islamicIdentity;

  /// No description provided for @educationAndCareer.
  ///
  /// In en, this message translates to:
  /// **'Education & Career'**
  String get educationAndCareer;

  /// No description provided for @aboutYou.
  ///
  /// In en, this message translates to:
  /// **'About You'**
  String get aboutYou;

  /// No description provided for @dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get dateOfBirth;

  /// No description provided for @tapToSelect.
  ///
  /// In en, this message translates to:
  /// **'Tap to select'**
  String get tapToSelect;

  /// No description provided for @mustBe18.
  ///
  /// In en, this message translates to:
  /// **'You must be 18+'**
  String get mustBe18;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @hijraDestination.
  ///
  /// In en, this message translates to:
  /// **'Hijra destination country'**
  String get hijraDestination;

  /// No description provided for @hijraHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Malaysia, Turkey, Jordan'**
  String get hijraHint;

  /// No description provided for @games.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get games;

  /// No description provided for @matchMemory.
  ///
  /// In en, this message translates to:
  /// **'Match Memory'**
  String get matchMemory;

  /// No description provided for @readyToBegin.
  ///
  /// In en, this message translates to:
  /// **'Ready to begin?'**
  String get readyToBegin;

  /// No description provided for @startBismillah.
  ///
  /// In en, this message translates to:
  /// **'Start — Bismillah'**
  String get startBismillah;

  /// No description provided for @waitingForMatch.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your match'**
  String get waitingForMatch;

  /// No description provided for @matchNotified.
  ///
  /// In en, this message translates to:
  /// **'They have been notified'**
  String get matchNotified;

  /// No description provided for @mashAllahComplete.
  ///
  /// In en, this message translates to:
  /// **'Masha\'Allah — Complete!'**
  String get mashAllahComplete;

  /// No description provided for @addedToMatchMemory.
  ///
  /// In en, this message translates to:
  /// **'Added to your Match Memory.'**
  String get addedToMatchMemory;

  /// No description provided for @turnHistory.
  ///
  /// In en, this message translates to:
  /// **'Turn History'**
  String get turnHistory;

  /// No description provided for @waitingForMatchAnswer.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your match\'s answer...'**
  String get waitingForMatchAnswer;

  /// No description provided for @answersHiddenUntil.
  ///
  /// In en, this message translates to:
  /// **'Both answers are hidden until both respond'**
  String get answersHiddenUntil;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @noMoreQuestions.
  ///
  /// In en, this message translates to:
  /// **'No more questions'**
  String get noMoreQuestions;

  /// No description provided for @gameWrappingUp.
  ///
  /// In en, this message translates to:
  /// **'This game is wrapping up!'**
  String get gameWrappingUp;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @lastSeenRecently.
  ///
  /// In en, this message translates to:
  /// **'Last seen recently'**
  String get lastSeenRecently;

  /// No description provided for @chaperonedCall.
  ///
  /// In en, this message translates to:
  /// **'Chaperoned call'**
  String get chaperonedCall;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @waitingForFamilyBlessings.
  ///
  /// In en, this message translates to:
  /// **'Waiting for family blessings'**
  String get waitingForFamilyBlessings;

  /// No description provided for @bismillahBeginBest.
  ///
  /// In en, this message translates to:
  /// **'Bismillah — begin with the best'**
  String get bismillahBeginBest;

  /// No description provided for @startConversation.
  ///
  /// In en, this message translates to:
  /// **'Start the conversation...'**
  String get startConversation;

  /// No description provided for @salamGreeting.
  ///
  /// In en, this message translates to:
  /// **'السَّلَامُ عَلَيْكُمْ وَرَحْمَةُ اللَّهِ وَبَرَكَاتُهُ'**
  String get salamGreeting;

  /// No description provided for @ringing.
  ///
  /// In en, this message translates to:
  /// **'Ringing...'**
  String get ringing;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @cameraOff.
  ///
  /// In en, this message translates to:
  /// **'(Camera off)'**
  String get cameraOff;

  /// No description provided for @guardianPresent.
  ///
  /// In en, this message translates to:
  /// **'Guardian present'**
  String get guardianPresent;

  /// No description provided for @guardianInvited.
  ///
  /// In en, this message translates to:
  /// **'Guardian invited'**
  String get guardianInvited;

  /// No description provided for @unmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @startCam.
  ///
  /// In en, this message translates to:
  /// **'Start cam'**
  String get startCam;

  /// No description provided for @stopCam.
  ///
  /// In en, this message translates to:
  /// **'Stop cam'**
  String get stopCam;

  /// No description provided for @speaker.
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get speaker;

  /// No description provided for @earpiece.
  ///
  /// In en, this message translates to:
  /// **'Earpiece'**
  String get earpiece;

  /// No description provided for @flip.
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get flip;

  /// No description provided for @endCall.
  ///
  /// In en, this message translates to:
  /// **'End call'**
  String get endCall;

  /// No description provided for @endThisCall.
  ///
  /// In en, this message translates to:
  /// **'End this call?'**
  String get endThisCall;

  /// No description provided for @allParticipantsDisconnected.
  ///
  /// In en, this message translates to:
  /// **'All participants will be disconnected.'**
  String get allParticipantsDisconnected;

  /// No description provided for @stayInCall.
  ///
  /// In en, this message translates to:
  /// **'Stay in call'**
  String get stayInCall;

  /// No description provided for @pushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get pushNotifications;

  /// No description provided for @pushNotificationsDesc.
  ///
  /// In en, this message translates to:
  /// **'New matches, messages, game turns'**
  String get pushNotificationsDesc;

  /// No description provided for @biometricLock.
  ///
  /// In en, this message translates to:
  /// **'Biometric lock'**
  String get biometricLock;

  /// No description provided for @guardianWali.
  ///
  /// In en, this message translates to:
  /// **'Guardian (Wali)'**
  String get guardianWali;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @showPhotoBeforeMutual.
  ///
  /// In en, this message translates to:
  /// **'Show photo before mutual interest'**
  String get showPhotoBeforeMutual;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of service'**
  String get termsOfService;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get contactSupport;

  /// No description provided for @rateMiskMatch.
  ///
  /// In en, this message translates to:
  /// **'Rate MiskMatch'**
  String get rateMiskMatch;

  /// No description provided for @sealIsMusk.
  ///
  /// In en, this message translates to:
  /// **'ختامه مسك'**
  String get sealIsMusk;

  /// No description provided for @sealIsMuskTranslation.
  ///
  /// In en, this message translates to:
  /// **'\"Its seal is musk.\" — Quran 83:26'**
  String get sealIsMuskTranslation;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOut;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get deleteAccount;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone. All your data will be permanently deleted.'**
  String get deleteAccountWarning;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @activeMatches.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeMatches;

  /// No description provided for @awaitingFamilies.
  ///
  /// In en, this message translates to:
  /// **'Awaiting families'**
  String get awaitingFamilies;

  /// No description provided for @matches.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get matches;

  /// No description provided for @noActiveMatchesYet.
  ///
  /// In en, this message translates to:
  /// **'No active matches yet'**
  String get noActiveMatchesYet;

  /// No description provided for @noPendingMatchesYet.
  ///
  /// In en, this message translates to:
  /// **'No pending matches yet'**
  String get noPendingMatchesYet;

  /// No description provided for @closeMatch.
  ///
  /// In en, this message translates to:
  /// **'Close match'**
  String get closeMatch;

  /// No description provided for @noMatchesYet.
  ///
  /// In en, this message translates to:
  /// **'No matches yet'**
  String get noMatchesYet;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// No description provided for @completeProfileMoreMatches.
  ///
  /// In en, this message translates to:
  /// **'Complete profile — 3× more matches'**
  String get completeProfileMoreMatches;

  /// No description provided for @sortedByCompatibility.
  ///
  /// In en, this message translates to:
  /// **'Sorted by compatibility'**
  String get sortedByCompatibility;

  /// No description provided for @noMoreCandidates.
  ///
  /// In en, this message translates to:
  /// **'No candidates yet'**
  String get noMoreCandidates;

  /// No description provided for @mayAllahMakeItKhayr.
  ///
  /// In en, this message translates to:
  /// **'May Allah make it khayr'**
  String get mayAllahMakeItKhayr;

  /// No description provided for @resendInCountdown.
  ///
  /// In en, this message translates to:
  /// **'Resend in {time}'**
  String resendInCountdown(String time);

  /// No description provided for @deen.
  ///
  /// In en, this message translates to:
  /// **'Deen'**
  String get deen;

  /// No description provided for @personality.
  ///
  /// In en, this message translates to:
  /// **'Personality'**
  String get personality;

  /// No description provided for @practical.
  ///
  /// In en, this message translates to:
  /// **'Practical'**
  String get practical;

  /// No description provided for @matchDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Match Day {day}'**
  String matchDayLabel(String day);

  /// No description provided for @gamesUnlockedCount.
  ///
  /// In en, this message translates to:
  /// **'{unlocked} of {total} unlocked'**
  String gamesUnlockedCount(String unlocked, String total);

  /// No description provided for @yourTurnInGame.
  ///
  /// In en, this message translates to:
  /// **'Your turn in {name}'**
  String yourTurnInGame(String name);

  /// No description provided for @yourTurnInGames.
  ///
  /// In en, this message translates to:
  /// **'Your turn in {count} games'**
  String yourTurnInGames(String count);

  /// No description provided for @tapGameToRespond.
  ///
  /// In en, this message translates to:
  /// **'Tap a game to respond'**
  String get tapGameToRespond;

  /// No description provided for @storyJustBeginning.
  ///
  /// In en, this message translates to:
  /// **'Your story is just beginning'**
  String get storyJustBeginning;

  /// No description provided for @completeGamesTimeline.
  ///
  /// In en, this message translates to:
  /// **'Complete games to fill the timeline'**
  String get completeGamesTimeline;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @accountActions.
  ///
  /// In en, this message translates to:
  /// **'Account Actions'**
  String get accountActions;

  /// No description provided for @signOutBody.
  ///
  /// In en, this message translates to:
  /// **'You can always sign back in later.'**
  String get signOutBody;

  /// No description provided for @deleteMyAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteMyAccount;

  /// No description provided for @writeYourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Write your answer...'**
  String get writeYourAnswer;

  /// No description provided for @theirMessage.
  ///
  /// In en, this message translates to:
  /// **'Their message'**
  String get theirMessage;

  /// No description provided for @noMessageProvided.
  ///
  /// In en, this message translates to:
  /// **'No message provided'**
  String get noMessageProvided;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @approveThisMatch.
  ///
  /// In en, this message translates to:
  /// **'Approve this match?'**
  String get approveThisMatch;

  /// No description provided for @declineThisMatch.
  ///
  /// In en, this message translates to:
  /// **'Decline this match?'**
  String get declineThisMatch;

  /// No description provided for @matchApprovedMsg.
  ///
  /// In en, this message translates to:
  /// **'Match approved — may Allah bless this union.'**
  String get matchApprovedMsg;

  /// No description provided for @matchDeclinedMsg.
  ///
  /// In en, this message translates to:
  /// **'Match declined.'**
  String get matchDeclinedMsg;

  /// No description provided for @notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptional;

  /// No description provided for @approveGuidanceHint.
  ///
  /// In en, this message translates to:
  /// **'As a guardian, your approval means you trust this match for your ward.'**
  String get approveGuidanceHint;

  /// No description provided for @yesApprove.
  ///
  /// In en, this message translates to:
  /// **'Yes, approve'**
  String get yesApprove;

  /// No description provided for @yesDecline.
  ///
  /// In en, this message translates to:
  /// **'Yes, decline'**
  String get yesDecline;

  /// No description provided for @goBackNotDecided.
  ///
  /// In en, this message translates to:
  /// **'Go back — not decided'**
  String get goBackNotDecided;

  /// No description provided for @noActiveMatches.
  ///
  /// In en, this message translates to:
  /// **'No active matches'**
  String get noActiveMatches;

  /// No description provided for @messageBlockedNotice.
  ///
  /// In en, this message translates to:
  /// **'Message blocked by moderation'**
  String get messageBlockedNotice;

  /// No description provided for @flagged.
  ///
  /// In en, this message translates to:
  /// **'Flagged'**
  String get flagged;

  /// No description provided for @flaggedInChat.
  ///
  /// In en, this message translates to:
  /// **'{name} flagged in chat'**
  String flaggedInChat(String name);

  /// No description provided for @fromSender.
  ///
  /// In en, this message translates to:
  /// **'From {name}'**
  String fromSender(String name);

  /// No description provided for @flaggedReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String flaggedReason(String reason);

  /// No description provided for @activeMatchesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} active matches'**
  String activeMatchesCount(String count);

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastName;

  /// No description provided for @continueBtn.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueBtn;

  /// No description provided for @saveProfileBismillah.
  ///
  /// In en, this message translates to:
  /// **'Save my profile — Bismillah'**
  String get saveProfileBismillah;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved. JazakAllah Khair'**
  String get profileSaved;

  /// No description provided for @profileSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save profile. Please try again.'**
  String get profileSaveFailed;

  /// No description provided for @tellUsAboutYourself.
  ///
  /// In en, this message translates to:
  /// **'Tell us about yourself'**
  String get tellUsAboutYourself;

  /// No description provided for @howOthersSeeYou.
  ///
  /// In en, this message translates to:
  /// **'This is how others will see you on MiskMatch.'**
  String get howOthersSeeYou;

  /// No description provided for @islamicPracticeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share your Islamic practice — the foundation of compatibility.'**
  String get islamicPracticeSubtitle;

  /// No description provided for @lifeGoalsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shared life goals are a strong compatibility signal.'**
  String get lifeGoalsSubtitle;

  /// No description provided for @educationCareerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Optional — helps find compatible life trajectories.'**
  String get educationCareerSubtitle;

  /// No description provided for @aboutYouSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This is the richest signal for AI compatibility matching.'**
  String get aboutYouSubtitle;

  /// No description provided for @stepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {current}/{total}'**
  String stepOf(String current, String total);

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @prayerFrequency.
  ///
  /// In en, this message translates to:
  /// **'Prayer frequency'**
  String get prayerFrequency;

  /// No description provided for @madhab.
  ///
  /// In en, this message translates to:
  /// **'Madhab'**
  String get madhab;

  /// No description provided for @quranLevel.
  ///
  /// In en, this message translates to:
  /// **'Quran level'**
  String get quranLevel;

  /// No description provided for @hijab.
  ///
  /// In en, this message translates to:
  /// **'Hijab'**
  String get hijab;

  /// No description provided for @children.
  ///
  /// In en, this message translates to:
  /// **'Children'**
  String get children;

  /// No description provided for @hajjTimeline.
  ///
  /// In en, this message translates to:
  /// **'Hajj timeline'**
  String get hajjTimeline;

  /// No description provided for @islamicFinanceStance.
  ///
  /// In en, this message translates to:
  /// **'Islamic finance stance'**
  String get islamicFinanceStance;

  /// No description provided for @wifeWorking.
  ///
  /// In en, this message translates to:
  /// **'Wife working stance'**
  String get wifeWorking;

  /// No description provided for @educationLevel.
  ///
  /// In en, this message translates to:
  /// **'Education level'**
  String get educationLevel;

  /// No description provided for @occupation.
  ///
  /// In en, this message translates to:
  /// **'Occupation'**
  String get occupation;

  /// No description provided for @iAmRevert.
  ///
  /// In en, this message translates to:
  /// **'I am a Muslim revert'**
  String get iAmRevert;

  /// No description provided for @yearOfReversion.
  ///
  /// In en, this message translates to:
  /// **'Year of reversion'**
  String get yearOfReversion;

  /// No description provided for @iWantHijra.
  ///
  /// In en, this message translates to:
  /// **'I want to make hijra'**
  String get iWantHijra;

  /// No description provided for @recordVoiceIntro.
  ///
  /// In en, this message translates to:
  /// **'Record your voice introduction'**
  String get recordVoiceIntro;

  /// No description provided for @voiceIntroLimit.
  ///
  /// In en, this message translates to:
  /// **'60 seconds maximum. Let them hear you before they see you.'**
  String get voiceIntroLimit;

  /// No description provided for @tapToRecord.
  ///
  /// In en, this message translates to:
  /// **'Tap to record'**
  String get tapToRecord;

  /// No description provided for @recording.
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get recording;

  /// No description provided for @tapToStop.
  ///
  /// In en, this message translates to:
  /// **'Tap to stop'**
  String get tapToStop;

  /// No description provided for @voiceRecorded.
  ///
  /// In en, this message translates to:
  /// **'Voice intro recorded'**
  String get voiceRecorded;

  /// No description provided for @deleteRecording.
  ///
  /// In en, this message translates to:
  /// **'Delete recording'**
  String get deleteRecording;

  /// No description provided for @playRecording.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playRecording;

  /// No description provided for @bioHint.
  ///
  /// In en, this message translates to:
  /// **'A practicing Muslim from Amman. I value family deeply and strive to make Islam central to every day...'**
  String get bioHint;

  /// No description provided for @aiMatchTip.
  ///
  /// In en, this message translates to:
  /// **'Your bio is read by our AI to find deeper matches'**
  String get aiMatchTip;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get fieldRequired;

  /// No description provided for @firstNameRequired.
  ///
  /// In en, this message translates to:
  /// **'First name is required'**
  String get firstNameRequired;

  /// No description provided for @lastNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Last name is required'**
  String get lastNameRequired;

  /// No description provided for @dateOfBirthRequired.
  ///
  /// In en, this message translates to:
  /// **'Date of birth is required'**
  String get dateOfBirthRequired;

  /// No description provided for @pleaseFillRequired.
  ///
  /// In en, this message translates to:
  /// **'Please fill in the required fields'**
  String get pleaseFillRequired;

  /// No description provided for @madhabHanafi.
  ///
  /// In en, this message translates to:
  /// **'Hanafi'**
  String get madhabHanafi;

  /// No description provided for @madhabMaliki.
  ///
  /// In en, this message translates to:
  /// **'Maliki'**
  String get madhabMaliki;

  /// No description provided for @madhabShafii.
  ///
  /// In en, this message translates to:
  /// **'Shafi\'i'**
  String get madhabShafii;

  /// No description provided for @madhabHanbali.
  ///
  /// In en, this message translates to:
  /// **'Hanbali'**
  String get madhabHanbali;

  /// No description provided for @madhabOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get madhabOther;

  /// No description provided for @prayerAll5.
  ///
  /// In en, this message translates to:
  /// **'All 5 daily prayers'**
  String get prayerAll5;

  /// No description provided for @prayerMost.
  ///
  /// In en, this message translates to:
  /// **'Most prayers'**
  String get prayerMost;

  /// No description provided for @prayerSometimes.
  ///
  /// In en, this message translates to:
  /// **'Sometimes'**
  String get prayerSometimes;

  /// No description provided for @prayerFridayOnly.
  ///
  /// In en, this message translates to:
  /// **'Friday only'**
  String get prayerFridayOnly;

  /// No description provided for @prayerWorkingOnIt.
  ///
  /// In en, this message translates to:
  /// **'Working on it'**
  String get prayerWorkingOnIt;

  /// No description provided for @hijabWears.
  ///
  /// In en, this message translates to:
  /// **'Wears hijab'**
  String get hijabWears;

  /// No description provided for @hijabOpenTo.
  ///
  /// In en, this message translates to:
  /// **'Open to hijab'**
  String get hijabOpenTo;

  /// No description provided for @hijabFamilyDecides.
  ///
  /// In en, this message translates to:
  /// **'Family decides'**
  String get hijabFamilyDecides;

  /// No description provided for @hijabPreference.
  ///
  /// In en, this message translates to:
  /// **'Preference'**
  String get hijabPreference;

  /// No description provided for @hijabNA.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get hijabNA;

  /// No description provided for @memberSince.
  ///
  /// In en, this message translates to:
  /// **'Member since {date}'**
  String memberSince(String date);

  /// No description provided for @prayer.
  ///
  /// In en, this message translates to:
  /// **'Prayer'**
  String get prayer;

  /// No description provided for @revert.
  ///
  /// In en, this message translates to:
  /// **'Revert'**
  String get revert;

  /// No description provided for @cropPhoto.
  ///
  /// In en, this message translates to:
  /// **'Crop Photo'**
  String get cropPhoto;

  /// No description provided for @waliRelFather.
  ///
  /// In en, this message translates to:
  /// **'Father'**
  String get waliRelFather;

  /// No description provided for @waliRelBrother.
  ///
  /// In en, this message translates to:
  /// **'Brother'**
  String get waliRelBrother;

  /// No description provided for @waliRelUncle.
  ///
  /// In en, this message translates to:
  /// **'Uncle'**
  String get waliRelUncle;

  /// No description provided for @waliRelGrandfather.
  ///
  /// In en, this message translates to:
  /// **'Grandfather'**
  String get waliRelGrandfather;

  /// No description provided for @waliRelImam.
  ///
  /// In en, this message translates to:
  /// **'Imam'**
  String get waliRelImam;

  /// No description provided for @waliRelOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get waliRelOther;

  /// No description provided for @filterProfiles.
  ///
  /// In en, this message translates to:
  /// **'Filter profiles'**
  String get filterProfiles;

  /// No description provided for @refreshFeed.
  ///
  /// In en, this message translates to:
  /// **'Refresh feed'**
  String get refreshFeed;

  /// No description provided for @fieldsRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} fields remaining'**
  String fieldsRemaining(String count);

  /// No description provided for @candidatesForYou.
  ///
  /// In en, this message translates to:
  /// **'{count} candidates for you'**
  String candidatesForYou(String count);

  /// No description provided for @writePersonalisedMsg.
  ///
  /// In en, this message translates to:
  /// **'Write a personalised message...'**
  String get writePersonalisedMsg;

  /// No description provided for @match.
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get match;

  /// No description provided for @biometricLockDesc.
  ///
  /// In en, this message translates to:
  /// **'Require Face ID / fingerprint on open'**
  String get biometricLockDesc;

  /// No description provided for @photoVisibleOff.
  ///
  /// In en, this message translates to:
  /// **'Off — photo revealed only after both sides show interest'**
  String get photoVisibleOff;

  /// No description provided for @invitationResent.
  ///
  /// In en, this message translates to:
  /// **'Invitation resent.'**
  String get invitationResent;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @ageRange.
  ///
  /// In en, this message translates to:
  /// **'Age range'**
  String get ageRange;

  /// No description provided for @anyCountry.
  ///
  /// In en, this message translates to:
  /// **'Any country'**
  String get anyCountry;

  /// No description provided for @anyMadhab.
  ///
  /// In en, this message translates to:
  /// **'Any madhab'**
  String get anyMadhab;

  /// No description provided for @anyPrayer.
  ///
  /// In en, this message translates to:
  /// **'Any prayer level'**
  String get anyPrayer;

  /// No description provided for @applyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply filters'**
  String get applyFilters;

  /// No description provided for @resetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetFilters;

  /// No description provided for @filtersActive.
  ///
  /// In en, this message translates to:
  /// **'Filters active'**
  String get filtersActive;

  /// No description provided for @gameDescriptionIntro.
  ///
  /// In en, this message translates to:
  /// **'This game will help you and your match discover each other through meaningful questions. Answer honestly — your wali can see all responses.'**
  String get gameDescriptionIntro;

  /// No description provided for @notificationOnYourTurn.
  ///
  /// In en, this message translates to:
  /// **'You\'ll receive a notification when it\'s your turn.'**
  String get notificationOnYourTurn;

  /// No description provided for @turnOf.
  ///
  /// In en, this message translates to:
  /// **'Turn {current} of {total}'**
  String turnOf(String current, String total);

  /// No description provided for @bothAnswered.
  ///
  /// In en, this message translates to:
  /// **'Both answered!'**
  String get bothAnswered;

  /// No description provided for @answersRevealed.
  ///
  /// In en, this message translates to:
  /// **'Answers revealed!'**
  String get answersRevealed;

  /// No description provided for @raceResults.
  ///
  /// In en, this message translates to:
  /// **'Race results!'**
  String get raceResults;

  /// No description provided for @reveal.
  ///
  /// In en, this message translates to:
  /// **'Reveal!'**
  String get reveal;

  /// No description provided for @gameCompleteMashaAllah.
  ///
  /// In en, this message translates to:
  /// **'Masha\'Allah — Game complete!'**
  String get gameCompleteMashaAllah;

  /// No description provided for @nextQuestion.
  ///
  /// In en, this message translates to:
  /// **'Next question'**
  String get nextQuestion;

  /// No description provided for @yourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get yourAnswer;

  /// No description provided for @theirAnswer.
  ///
  /// In en, this message translates to:
  /// **'Their answer'**
  String get theirAnswer;

  /// No description provided for @correct.
  ///
  /// In en, this message translates to:
  /// **'Correct: '**
  String get correct;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @vs.
  ///
  /// In en, this message translates to:
  /// **'vs'**
  String get vs;

  /// No description provided for @them.
  ///
  /// In en, this message translates to:
  /// **'Them'**
  String get them;

  /// No description provided for @sameChoiceMashaAllah.
  ///
  /// In en, this message translates to:
  /// **'You both chose the same! Masha\'Allah'**
  String get sameChoiceMashaAllah;

  /// No description provided for @differentChoices.
  ///
  /// In en, this message translates to:
  /// **'You chose differently — great conversation starter!'**
  String get differentChoices;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @submitAnswer.
  ///
  /// In en, this message translates to:
  /// **'Submit answer'**
  String get submitAnswer;

  /// No description provided for @submitRanking.
  ///
  /// In en, this message translates to:
  /// **'Submit ranking'**
  String get submitRanking;

  /// No description provided for @dragToRank.
  ///
  /// In en, this message translates to:
  /// **'Drag to rank from most to least important:'**
  String get dragToRank;

  /// No description provided for @notAtAll.
  ///
  /// In en, this message translates to:
  /// **'1 — Not at all'**
  String get notAtAll;

  /// No description provided for @absolutely.
  ///
  /// In en, this message translates to:
  /// **'10 — Absolutely'**
  String get absolutely;

  /// No description provided for @completeSentence.
  ///
  /// In en, this message translates to:
  /// **'Complete the sentence'**
  String get completeSentence;

  /// No description provided for @moreCharsNeeded.
  ///
  /// In en, this message translates to:
  /// **'{count} more characters needed'**
  String moreCharsNeeded(String count);

  /// No description provided for @dayNumber.
  ///
  /// In en, this message translates to:
  /// **'Day {day}'**
  String dayNumber(String day);

  /// No description provided for @completeCheck.
  ///
  /// In en, this message translates to:
  /// **'Complete ✓'**
  String get completeCheck;

  /// No description provided for @waiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting...'**
  String get waiting;

  /// No description provided for @tapToStart.
  ///
  /// In en, this message translates to:
  /// **'Tap to start'**
  String get tapToStart;

  /// No description provided for @yourTurn.
  ///
  /// In en, this message translates to:
  /// **'Your turn'**
  String get yourTurn;

  /// No description provided for @timeCapsule.
  ///
  /// In en, this message translates to:
  /// **'Time Capsule'**
  String get timeCapsule;

  /// No description provided for @letterToFutureSelf.
  ///
  /// In en, this message translates to:
  /// **'A letter to your future selves'**
  String get letterToFutureSelf;

  /// No description provided for @timeCapsuleInstructions.
  ///
  /// In en, this message translates to:
  /// **'Write a letter to your future selves — your hopes for this relationship, a du\'a, a dream, or a message you want to read together on Day 21. Your partner will write theirs too. Neither of you can read them until the capsule opens.'**
  String get timeCapsuleInstructions;

  /// No description provided for @timeCapsuleHint.
  ///
  /// In en, this message translates to:
  /// **'Bismillah... dear future us,\n\nBy the time you read this...'**
  String get timeCapsuleHint;

  /// No description provided for @readyToSeal.
  ///
  /// In en, this message translates to:
  /// **'Ready to seal'**
  String get readyToSeal;

  /// No description provided for @moreCharsToSeal.
  ///
  /// In en, this message translates to:
  /// **'{count} more characters to seal'**
  String moreCharsToSeal(String count);

  /// No description provided for @sealCapsule.
  ///
  /// In en, this message translates to:
  /// **'Seal the Capsule'**
  String get sealCapsule;

  /// No description provided for @timeCapsuleSealed.
  ///
  /// In en, this message translates to:
  /// **'Time Capsule — Sealed'**
  String get timeCapsuleSealed;

  /// No description provided for @capsuleSealedDesc.
  ///
  /// In en, this message translates to:
  /// **'Your letters are safely sealed. They will be revealed together on Day 21.'**
  String get capsuleSealedDesc;

  /// No description provided for @opensIn.
  ///
  /// In en, this message translates to:
  /// **'Opens in'**
  String get opensIn;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get day;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get days;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get hours;

  /// No description provided for @min.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get min;

  /// No description provided for @sec.
  ///
  /// In en, this message translates to:
  /// **'sec'**
  String get sec;

  /// No description provided for @capsuleOpen.
  ///
  /// In en, this message translates to:
  /// **'Your Time Capsule is Open!'**
  String get capsuleOpen;

  /// No description provided for @readLetters.
  ///
  /// In en, this message translates to:
  /// **'Read your letters to each other.'**
  String get readLetters;

  /// No description provided for @capsuleIsOpen.
  ///
  /// In en, this message translates to:
  /// **'The capsule is open!'**
  String get capsuleIsOpen;

  /// No description provided for @lettersProcessing.
  ///
  /// In en, this message translates to:
  /// **'Your letters will appear here once processed.'**
  String get lettersProcessing;

  /// No description provided for @openCapsule.
  ///
  /// In en, this message translates to:
  /// **'Open the Time Capsule'**
  String get openCapsule;

  /// No description provided for @guardianCallInvite.
  ///
  /// In en, this message translates to:
  /// **'Guardian call invite'**
  String get guardianCallInvite;

  /// No description provided for @incomingCall.
  ///
  /// In en, this message translates to:
  /// **'Incoming call'**
  String get incomingCall;

  /// No description provided for @guardianInviteNote.
  ///
  /// In en, this message translates to:
  /// **'You have been invited as guardian to this call.'**
  String get guardianInviteNote;

  /// No description provided for @guardianChaperon.
  ///
  /// In en, this message translates to:
  /// **'Your guardian has been invited to join as chaperone.'**
  String get guardianChaperon;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @youLabel.
  ///
  /// In en, this message translates to:
  /// **'You — {name}'**
  String youLabel(String name);

  /// No description provided for @chaperonesCall.
  ///
  /// In en, this message translates to:
  /// **'Chaperoned call — guardian will be notified'**
  String get chaperonesCall;

  /// No description provided for @guardianObserver.
  ///
  /// In en, this message translates to:
  /// **'Your guardian will be invited to join as an observer. This is the blessed way — open communication with family.'**
  String get guardianObserver;

  /// No description provided for @audioOnly.
  ///
  /// In en, this message translates to:
  /// **'Audio only'**
  String get audioOnly;

  /// No description provided for @audioOnlyDesc.
  ///
  /// In en, this message translates to:
  /// **'No camera — audio call instead'**
  String get audioOnlyDesc;

  /// No description provided for @inviteGuardian.
  ///
  /// In en, this message translates to:
  /// **'Invite guardian'**
  String get inviteGuardian;

  /// No description provided for @inviteGuardianDesc.
  ///
  /// In en, this message translates to:
  /// **'Your wali will receive a call invite'**
  String get inviteGuardianDesc;

  /// No description provided for @scheduleLater.
  ///
  /// In en, this message translates to:
  /// **'Schedule for later'**
  String get scheduleLater;

  /// No description provided for @scheduleLaterDesc.
  ///
  /// In en, this message translates to:
  /// **'Pick a time instead of calling now'**
  String get scheduleLaterDesc;

  /// No description provided for @scheduleCall.
  ///
  /// In en, this message translates to:
  /// **'Schedule call'**
  String get scheduleCall;

  /// No description provided for @startCallNow.
  ///
  /// In en, this message translates to:
  /// **'Start call now'**
  String get startCallNow;

  /// No description provided for @scheduledTime.
  ///
  /// In en, this message translates to:
  /// **'Scheduled time'**
  String get scheduledTime;

  /// No description provided for @prayerAllFive.
  ///
  /// In en, this message translates to:
  /// **'All 5 daily prayers'**
  String get prayerAllFive;

  /// No description provided for @prayerWorkingOn.
  ///
  /// In en, this message translates to:
  /// **'Working on it'**
  String get prayerWorkingOn;

  /// No description provided for @quranHafiz.
  ///
  /// In en, this message translates to:
  /// **'Full Hafiz'**
  String get quranHafiz;

  /// No description provided for @quranPartialHafiz.
  ///
  /// In en, this message translates to:
  /// **'Partial Hafiz'**
  String get quranPartialHafiz;

  /// No description provided for @quranMemorising.
  ///
  /// In en, this message translates to:
  /// **'Currently memorising'**
  String get quranMemorising;

  /// No description provided for @quranTajweed.
  ///
  /// In en, this message translates to:
  /// **'Recites with Tajweed'**
  String get quranTajweed;

  /// No description provided for @quranStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong recitation'**
  String get quranStrong;

  /// No description provided for @quranLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get quranLearning;

  /// No description provided for @quranBeginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get quranBeginner;

  /// No description provided for @revertLabel.
  ///
  /// In en, this message translates to:
  /// **'Revert'**
  String get revertLabel;

  /// No description provided for @revertYear.
  ///
  /// In en, this message translates to:
  /// **'Revert {year}'**
  String revertYear(String year);

  /// No description provided for @quran.
  ///
  /// In en, this message translates to:
  /// **'Quran'**
  String get quran;

  /// No description provided for @journey.
  ///
  /// In en, this message translates to:
  /// **'Journey'**
  String get journey;

  /// No description provided for @trustScore.
  ///
  /// In en, this message translates to:
  /// **'Trust'**
  String get trustScore;

  /// No description provided for @mosqueVerified.
  ///
  /// In en, this message translates to:
  /// **'Mosque verified'**
  String get mosqueVerified;

  /// No description provided for @scholarEndorsed.
  ///
  /// In en, this message translates to:
  /// **'Scholar endorsed'**
  String get scholarEndorsed;

  /// No description provided for @gamesCompleted.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get gamesCompleted;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @accountDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account deleted successfully.'**
  String get accountDeletedSuccess;

  /// No description provided for @themeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// No description provided for @themeDescription.
  ///
  /// In en, this message translates to:
  /// **'Rose Garden / Musk Night'**
  String get themeDescription;

  /// No description provided for @loadingGuardianStatus.
  ///
  /// In en, this message translates to:
  /// **'Loading guardian status...'**
  String get loadingGuardianStatus;

  /// No description provided for @guardianStatus.
  ///
  /// In en, this message translates to:
  /// **'Guardian status'**
  String get guardianStatus;

  /// No description provided for @guardianLabel.
  ///
  /// In en, this message translates to:
  /// **'Guardian'**
  String get guardianLabel;

  /// No description provided for @notSetUp.
  ///
  /// In en, this message translates to:
  /// **'Not set up'**
  String get notSetUp;

  /// No description provided for @statusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @resendGuardianInvite.
  ///
  /// In en, this message translates to:
  /// **'Resend guardian invite'**
  String get resendGuardianInvite;

  /// No description provided for @copyMessage.
  ///
  /// In en, this message translates to:
  /// **'Copy message'**
  String get copyMessage;

  /// No description provided for @messageCopied.
  ///
  /// In en, this message translates to:
  /// **'Message copied'**
  String get messageCopied;

  /// No description provided for @reportMessage.
  ///
  /// In en, this message translates to:
  /// **'Report message'**
  String get reportMessage;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @interestSentTo.
  ///
  /// In en, this message translates to:
  /// **'Interest sent to {name}. JazakAllah Khair 🌙'**
  String interestSentTo(String name);

  /// No description provided for @interestSentToShort.
  ///
  /// In en, this message translates to:
  /// **'Interest sent to {name}'**
  String interestSentToShort(String name);

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @pleaseRestartApp.
  ///
  /// In en, this message translates to:
  /// **'Please restart the app.\nWe apologise for the inconvenience.'**
  String get pleaseRestartApp;

  /// No description provided for @guardianPortal.
  ///
  /// In en, this message translates to:
  /// **'Guardian Portal'**
  String get guardianPortal;

  /// No description provided for @permissionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permissionsLabel;

  /// No description provided for @profileOverview.
  ///
  /// In en, this message translates to:
  /// **'Profile overview'**
  String get profileOverview;

  /// No description provided for @ourJourney.
  ///
  /// In en, this message translates to:
  /// **'Our Journey'**
  String get ourJourney;

  /// No description provided for @writePersonalisedMessage.
  ///
  /// In en, this message translates to:
  /// **'Write a personalised message...'**
  String get writePersonalisedMessage;

  /// No description provided for @profileCompletionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add: {fields}'**
  String profileCompletionAdd(String fields);

  /// No description provided for @revertSinceYear.
  ///
  /// In en, this message translates to:
  /// **'Since {year}'**
  String revertSinceYear(String year);

  /// No description provided for @revertYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get revertYes;

  /// No description provided for @wantsChildrenCount.
  ///
  /// In en, this message translates to:
  /// **'👶 Wants {count} children'**
  String wantsChildrenCount(String count);

  /// No description provided for @wantsChildren.
  ///
  /// In en, this message translates to:
  /// **'👶 Wants children'**
  String get wantsChildren;

  /// No description provided for @noChildren.
  ///
  /// In en, this message translates to:
  /// **'👶 No children'**
  String get noChildren;

  /// No description provided for @selfIndicator.
  ///
  /// In en, this message translates to:
  /// **'You — {name}'**
  String selfIndicator(String name);
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return SAr();
    case 'en':
      return SEn();
  }

  throw FlutterError(
      'S.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
