// GENERATED FILE — DO NOT EDIT.
// Regenerate with: flutter gen-l10n
//
// This file provides the S class for accessing localized strings.
// Usage: S.of(context).appName

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

/// Callers can look up localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their
/// `localizationsDelegates` list, and the locales in
/// `supportedLocales`:
///
/// ```dart
/// localizationsDelegates: [
///   S.delegate,
///   GlobalMaterialLocalizations.delegate,
///   GlobalWidgetsLocalizations.delegate,
///   GlobalCupertinoLocalizations.delegate,
/// ],
/// supportedLocales: S.supportedLocales,
/// ```
abstract class S {
  S(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S of(BuildContext context) {
    return Localizations.of<S>(context, S)!;
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ar'),
  ];

  // ── App info ──────────────────────────────────────────────────────────────
  String get appName;
  String get appTagline;
  String get quranRef;

  // ── Auth — Phone screen ───────────────────────────────────────────────────
  String get findYourOtherHalf;
  String get islamicWayTagline;
  String get enterYourNumber;
  String get verificationCodeHint;
  String get phoneNumber;
  String get phoneHint;
  String get enterValidPhone;
  String get password;
  String get passwordHint;
  String get passwordMinLength;
  String get createAccount;
  String get signIn;
  String get newAccount;
  String get byContAgreement;
  String get terms;
  String get privacyPolicy;
  String get guardianInformed;
  String get iAmA;
  String get brother;
  String get sister;
  String get selectCountry;
  String get search;
  String get countryNameOrCode;

  // ── Auth — OTP screen ─────────────────────────────────────────────────────
  String get enterVerificationCode;
  String get otpSentHint;
  String get verifyAndContinue;
  String get resendCode;
  String get otpPrivacyNote;
  String get verifyYourNumber;
  String get change;

  // ── Auth — Niyyah screen ──────────────────────────────────────────────────
  String get bismillahDua;
  String get bismillahTranslation;
  String get setYourNiyyah;
  String get niyyahDescription;
  String get niyyahMarriage;
  String get niyyahRighteous;
  String get niyyahDeen;
  String get writeOwnNiyyah;
  String get declareNiyyah;
  String get setNiyyahLater;

  // ── Auth — Wali setup ─────────────────────────────────────────────────────
  String get yourGuardian;
  String get noMarriageWithoutGuardian;
  String get noMarriageTranslation;
  String get whoIsGuardian;
  String get selectRelationship;
  String get enterTheirDetails;
  String get smsInvitationHint;
  String get guardianFullName;
  String get guardianNameHint;
  String get pleaseEnterGuardianName;
  String get next;
  String get completeSetup;
  String get skipGuardianSetup;
  String get chooseInvolvement;
  String get changeSettingsLater;
  String get mustApproveMatches;
  String get mustApproveDesc;
  String get canReadConversations;
  String get canReadDesc;
  String get receivesNotifications;
  String get receivesNotifDesc;
  String get canJoinCalls;
  String get canJoinCallsDesc;
  String get required;

  // ── Profile ───────────────────────────────────────────────────────────────
  String get myProfile;
  String get editProfile;
  String get settings;
  String get updateProfilePhoto;
  String get takePhoto;
  String get chooseFromGallery;
  String get photoUpdated;
  String get photoUploadFailed;
  String get profileStrength;
  String get myVoiceIntro;
  String get islamicPractice;
  String get lifeGoals;
  String get aboutMe;
  String get readMore;
  String get showLess;
  String get completeYourProfile;
  String get completeProfileHint;
  String get setUpMyProfile;
  String get tryAgain;

  // ── Profile edit wizard ───────────────────────────────────────────────────
  String get basicInfo;
  String get islamicIdentity;
  String get educationAndCareer;
  String get aboutYou;
  String get dateOfBirth;
  String get tapToSelect;
  String get mustBe18;
  String get city;
  String get hijraDestination;
  String get hijraHint;

  // ── Games ─────────────────────────────────────────────────────────────────
  String get games;
  String get matchMemory;
  String get readyToBegin;
  String get startBismillah;
  String get waitingForMatch;
  String get matchNotified;
  String get mashAllahComplete;
  String get addedToMatchMemory;
  String get turnHistory;
  String get waitingForMatchAnswer;
  String get answersHiddenUntil;
  String get retry;
  String get noMoreQuestions;
  String get gameWrappingUp;

  // ── Chat ──────────────────────────────────────────────────────────────────
  String get online;
  String get lastSeenRecently;
  String get chaperonedCall;
  String get today;
  String get yesterday;
  String get waitingForFamilyBlessings;
  String get bismillahBeginBest;
  String get startConversation;
  String get salamGreeting;

  // ── Calls ─────────────────────────────────────────────────────────────────
  String get ringing;
  String get connecting;
  String get cameraOff;
  String get guardianPresent;
  String get guardianInvited;
  String get unmute;
  String get mute;
  String get startCam;
  String get stopCam;
  String get speaker;
  String get earpiece;
  String get flip;
  String get endCall;
  String get endThisCall;
  String get allParticipantsDisconnected;
  String get stayInCall;

  // ── Settings ──────────────────────────────────────────────────────────────
  String get pushNotifications;
  String get pushNotificationsDesc;
  String get biometricLock;
  String get guardianWali;
  String get appearance;
  String get privacy;
  String get showPhotoBeforeMutual;
  String get termsOfService;
  String get contactSupport;
  String get rateMiskMatch;
  String get sealIsMusk;
  String get sealIsMuskTranslation;
  String get signOut;
  String get deleteAccount;
  String get deleteAccountWarning;
  String get cancel;
  String get confirm;

  // ── Matches ───────────────────────────────────────────────────────────────
  String get activeMatches;
  String get awaitingFamilies;
  String get matches;
  String get noActiveMatchesYet;
  String get noPendingMatchesYet;
  String get closeMatch;
  String get noMatchesYet;
  String get chat;

  // ── Discovery ─────────────────────────────────────────────────────────────
  String get discover;
  String get completeProfileMoreMatches;
  String get sortedByCompatibility;
  String get noMoreCandidates;
  String get mayAllahMakeItKhayr;

  // ── Additional ────────────────────────────────────────────────────────────
  String get account;
  String get about;
  String get version;
  String get accountActions;
  String get signOutBody;
  String get deleteMyAccount;
  String get writeYourAnswer;
  String resendInCountdown(String time);

  // ── Games hub ─────────────────────────────────────────────────────────────
  String matchDayLabel(String day);
  String gamesUnlockedCount(String unlocked, String total);
  String yourTurnInGame(String name);
  String yourTurnInGames(String count);
  String get tapGameToRespond;
  String get storyJustBeginning;
  String get completeGamesTimeline;

  // ── Compatibility breakdown ───────────────────────────────────────────────
  String get deen;
  String get personality;
  String get practical;

  // ── Wali decisions ────────────────────────────────────────────────────────
  String get theirMessage;
  String get noMessageProvided;
  String get decline;
  String get approve;
  String get approveThisMatch;
  String get declineThisMatch;
  String get matchApprovedMsg;
  String get matchDeclinedMsg;
  String get notesOptional;
  String get approveGuidanceHint;
  String get yesApprove;
  String get yesDecline;
  String get goBackNotDecided;
  String get noActiveMatches;
  String get messageBlockedNotice;
  String get flagged;
  String flaggedInChat(String name);
  String fromSender(String name);
  String flaggedReason(String reason);
  String activeMatchesCount(String count);
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ar'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  switch (locale.languageCode) {
    case 'ar': return SAr();
    case 'en': return SEn();
  }
  throw FlutterError('S.delegate failed to load locale "${locale.languageCode}". '
      'Supported locales: en, ar.');
}
