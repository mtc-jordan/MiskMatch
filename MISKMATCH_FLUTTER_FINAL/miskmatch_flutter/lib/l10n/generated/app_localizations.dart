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

  /// No description provided for @videoCallsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Video calls coming soon'**
  String get videoCallsComingSoon;

  /// No description provided for @filtersComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Filters coming soon'**
  String get filtersComingSoon;
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
