/// MiskMatch — Profile Domain Models
/// Maps 1:1 with the FastAPI /profiles endpoints.

// ─────────────────────────────────────────────
// ENUMS  (mirror backend enum values)
// ─────────────────────────────────────────────

enum Madhab { hanafi, maliki, shafii, hanbali, other }
enum PrayerFrequency { allFive, most, sometimes, fridayOnly, workingOn }
enum HijabStance { wears, openTo, familyDecides, preference, na }
enum SubscriptionTier { barakah, noor, misk }

extension MadhabX on Madhab {
  String get value => switch (this) {
    Madhab.hanafi  => 'hanafi',
    Madhab.maliki  => 'maliki',
    Madhab.shafii  => 'shafii',
    Madhab.hanbali => 'hanbali',
    Madhab.other   => 'other',
  };
  String get label => switch (this) {
    Madhab.hanafi  => 'Hanafi',
    Madhab.maliki  => 'Maliki',
    Madhab.shafii  => "Shafi'i",
    Madhab.hanbali => 'Hanbali',
    Madhab.other   => 'Other',
  };
  static Madhab? fromValue(String? v) =>
      Madhab.values.where((e) => e.value == v).firstOrNull;
}

extension PrayerFrequencyX on PrayerFrequency {
  String get value => switch (this) {
    PrayerFrequency.allFive    => 'all_five',
    PrayerFrequency.most       => 'most',
    PrayerFrequency.sometimes  => 'sometimes',
    PrayerFrequency.fridayOnly => 'friday_only',
    PrayerFrequency.workingOn  => 'working_on',
  };
  String get label => switch (this) {
    PrayerFrequency.allFive    => 'All 5 daily prayers',
    PrayerFrequency.most       => 'Most prayers',
    PrayerFrequency.sometimes  => 'Sometimes',
    PrayerFrequency.fridayOnly => 'Friday only',
    PrayerFrequency.workingOn  => 'Working on it',
  };
  String get emoji => switch (this) {
    PrayerFrequency.allFive    => '🕌',
    PrayerFrequency.most       => '🕌',
    PrayerFrequency.sometimes  => '🕋',
    PrayerFrequency.fridayOnly => '🕋',
    PrayerFrequency.workingOn  => '📿',
  };
  static PrayerFrequency? fromValue(String? v) =>
      PrayerFrequency.values.where((e) => e.value == v).firstOrNull;
}

extension HijabStanceX on HijabStance {
  String get value => switch (this) {
    HijabStance.wears         => 'wears',
    HijabStance.openTo        => 'open_to',
    HijabStance.familyDecides => 'family_decides',
    HijabStance.preference    => 'preference',
    HijabStance.na            => 'na',
  };
  String get label => switch (this) {
    HijabStance.wears         => 'Wears hijab',
    HijabStance.openTo        => 'Open to hijab',
    HijabStance.familyDecides => 'Family decides',
    HijabStance.preference    => 'Preference',
    HijabStance.na            => 'N/A',
  };
  static HijabStance? fromValue(String? v) =>
      HijabStance.values.where((e) => e.value == v).firstOrNull;
}

// ─────────────────────────────────────────────
// PROFILE MODEL
// ─────────────────────────────────────────────

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.displayName,
    this.dateOfBirth,
    this.age,
    this.city,
    this.country,
    this.nationality,
    this.languages    = const [],
    this.bio,
    this.photoUrl,
    this.photos       = const [],
    this.voiceIntroUrl,
    this.photoVisible = false,
    this.madhab,
    this.prayerFrequency,
    this.hijabStance,
    this.quranLevel,
    this.isRevert     = false,
    this.revertYear,
    this.educationLevel,
    this.occupation,
    this.wantsChildren,
    this.numChildrenDesired,
    this.hajjTimeline,
    this.wantsHijra   = false,
    this.hijraCountry,
    this.islamicFinanceStance,
    this.wifeWorkingStance,
    this.sifrScores,
    this.loveLanguage,
    this.trustScore   = 0,
    this.mosqueVerified  = false,
    this.scholarEndorsed = false,
    this.idVerified   = false,
    this.minAge       = 22,
    this.maxAge       = 40,
    this.createdAt,
  });

  final String    userId;
  final String    firstName;
  final String    lastName;
  final String?   displayName;
  final DateTime? dateOfBirth;
  final int?      age;
  final String?   city;
  final String?   country;
  final String?   nationality;
  final List<String> languages;
  final String?   bio;
  final String?   photoUrl;
  final List<String> photos;
  final String?   voiceIntroUrl;
  final bool      photoVisible;

  // Islamic identity
  final Madhab?          madhab;
  final PrayerFrequency? prayerFrequency;
  final HijabStance?     hijabStance;
  final String?          quranLevel;
  final bool             isRevert;
  final int?             revertYear;

  // Education & career
  final String?   educationLevel;
  final String?   occupation;

  // Life goals
  final bool?     wantsChildren;
  final String?   numChildrenDesired;
  final String?   hajjTimeline;
  final bool      wantsHijra;
  final String?   hijraCountry;
  final String?   islamicFinanceStance;
  final String?   wifeWorkingStance;

  // Personality
  final Map<String, dynamic>? sifrScores;
  final String?   loveLanguage;

  // Trust
  final int    trustScore;
  final bool   mosqueVerified;
  final bool   scholarEndorsed;
  final bool   idVerified;

  // Preferences
  final int    minAge;
  final int    maxAge;

  // Metadata
  final DateTime? createdAt;

  // ── Computed helpers ─────────────────────────────────────────────────────
  String get displayFirstName => displayName ?? firstName;
  String get lastNameInitial  => lastName.isNotEmpty ? '${lastName[0]}.' : '';
  bool get hasVoiceIntro      => voiceIntroUrl != null;
  bool get hasPhoto           => photoUrl != null && photoVisible;

  String get locationText {
    if (city != null && country != null) return '$city, $country';
    if (city != null) return city!;
    if (country != null) return country!;
    return '';
  }

  String get prayerLabel  => prayerFrequency?.label ?? '';
  String get madhabLabel  => madhab?.label ?? '';
  String get hijabLabel   => hijabStance?.label ?? '';

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    userId:        json['user_id']       as String,
    firstName:     json['first_name']    as String,
    lastName:      json['last_name']     as String? ?? '',
    displayName:   json['display_name']  as String?,
    age:           json['age']           as int?,
    city:          json['city']          as String?,
    country:       json['country']       as String?,
    nationality:   json['nationality']   as String?,
    languages:     (json['languages']    as List<dynamic>?)
        ?.map((e) => e.toString()).toList() ?? [],
    bio:           json['bio']           as String?,
    photoUrl:      json['photo_url']     as String?,
    photos:        (json['photos']       as List<dynamic>?)
        ?.map((e) => e.toString()).toList() ?? [],
    voiceIntroUrl: json['voice_intro_url'] as String?,
    photoVisible:  json['photo_visible'] as bool? ?? false,
    madhab:        MadhabX.fromValue(json['madhab'] as String?),
    prayerFrequency: PrayerFrequencyX.fromValue(
        json['prayer_frequency'] as String?),
    hijabStance:   HijabStanceX.fromValue(json['hijab_stance'] as String?),
    quranLevel:    json['quran_level']   as String?,
    isRevert:      json['is_revert']     as bool? ?? false,
    revertYear:    json['revert_year']   as int?,
    educationLevel:json['education_level'] as String?,
    occupation:    json['occupation']    as String?,
    wantsChildren: json['wants_children']as bool?,
    numChildrenDesired: json['num_children_desired'] as String?,
    hajjTimeline:  json['hajj_timeline'] as String?,
    wantsHijra:    json['wants_hijra']   as bool? ?? false,
    hijraCountry:  json['hijra_country'] as String?,
    islamicFinanceStance: json['islamic_finance_stance'] as String?,
    wifeWorkingStance:    json['wife_working_stance']    as String?,
    sifrScores:    json['sifr_scores']   as Map<String, dynamic>?,
    loveLanguage:  json['love_language'] as String?,
    trustScore:    json['trust_score']   as int? ?? 0,
    mosqueVerified:  json['mosque_verified']   as bool? ?? false,
    scholarEndorsed: json['scholar_endorsed']  as bool? ?? false,
    idVerified:      json['id_verified'] == 'verified',
    minAge:        json['min_age']       as int? ?? 22,
    maxAge:        json['max_age']       as int? ?? 40,
    createdAt:     json['created_at'] != null
        ? DateTime.tryParse(json['created_at'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'first_name':   firstName,
    'last_name':    lastName,
    if (displayName != null)   'display_name':   displayName,
    if (dateOfBirth != null)   'date_of_birth':  dateOfBirth!.toUtc().toIso8601String(),
    if (city != null && city!.isNotEmpty) 'city': city,
    if (country != null)       'country':        country,
    if (bio != null)           'bio':            bio,
    if (madhab != null)        'madhab':         madhab!.value,
    if (prayerFrequency != null) 'prayer_frequency': prayerFrequency!.value,
    if (hijabStance != null)   'hijab_stance':   hijabStance!.value,
    if (quranLevel != null)    'quran_level':    quranLevel,
    'is_revert':    isRevert,
    if (wantsChildren != null) 'wants_children': wantsChildren,
    if (numChildrenDesired != null) 'num_children_desired': numChildrenDesired,
    if (hajjTimeline != null)  'hajj_timeline':  hajjTimeline,
    'wants_hijra':  wantsHijra,
    if (islamicFinanceStance != null) 'islamic_finance_stance': islamicFinanceStance,
    if (wifeWorkingStance != null) 'wife_working_stance': wifeWorkingStance,
    if (educationLevel != null) 'education_level': educationLevel,
    if (occupation != null && occupation!.isNotEmpty) 'occupation': occupation,
    'min_age':      minAge,
    'max_age':      maxAge,
  };

  UserProfile copyWith({
    String? firstName, String? lastName, String? bio,
    String? city, String? country, Madhab? madhab,
    PrayerFrequency? prayerFrequency, HijabStance? hijabStance,
    String? quranLevel, bool? isRevert, bool? wantsChildren,
    String? numChildrenDesired, String? hajjTimeline,
    bool? wantsHijra, String? islamicFinanceStance, String? wifeWorkingStance,
    String? photoUrl, String? voiceIntroUrl, int? minAge, int? maxAge,
    String? educationLevel, String? occupation,
  }) => UserProfile(
    userId:        userId,
    firstName:     firstName      ?? this.firstName,
    lastName:      lastName       ?? this.lastName,
    displayName:   displayName,
    age:           age,
    city:          city           ?? this.city,
    country:       country        ?? this.country,
    languages:     languages,
    bio:           bio            ?? this.bio,
    photoUrl:      photoUrl       ?? this.photoUrl,
    photos:        photos,
    voiceIntroUrl: voiceIntroUrl  ?? this.voiceIntroUrl,
    photoVisible:  photoVisible,
    madhab:        madhab         ?? this.madhab,
    prayerFrequency: prayerFrequency ?? this.prayerFrequency,
    hijabStance:   hijabStance    ?? this.hijabStance,
    quranLevel:    quranLevel     ?? this.quranLevel,
    isRevert:      isRevert       ?? this.isRevert,
    educationLevel:educationLevel ?? this.educationLevel,
    occupation:    occupation     ?? this.occupation,
    wantsChildren: wantsChildren  ?? this.wantsChildren,
    numChildrenDesired: numChildrenDesired ?? this.numChildrenDesired,
    hajjTimeline:  hajjTimeline   ?? this.hajjTimeline,
    wantsHijra:    wantsHijra     ?? this.wantsHijra,
    islamicFinanceStance: islamicFinanceStance ?? this.islamicFinanceStance,
    wifeWorkingStance:    wifeWorkingStance    ?? this.wifeWorkingStance,
    trustScore:    trustScore,
    mosqueVerified:  mosqueVerified,
    scholarEndorsed: scholarEndorsed,
    idVerified:      idVerified,
    minAge:        minAge         ?? this.minAge,
    maxAge:        maxAge         ?? this.maxAge,
    createdAt:     createdAt,
  );
}

// ─────────────────────────────────────────────
// PROFILE COMPLETION
// ─────────────────────────────────────────────

class ProfileCompletion {
  const ProfileCompletion({
    required this.percentage,
    required this.missingFields,
    required this.nextStep,
  });

  final int          percentage;
  final List<String> missingFields;
  final String?      nextStep;

  factory ProfileCompletion.fromJson(Map<String, dynamic> json) =>
      ProfileCompletion(
        percentage:    (json['completion_pct'] ?? json['percentage']) as int? ?? 0,
        missingFields: (json['missing_fields'] as List<dynamic>?)
            ?.map((e) => e.toString()).toList() ?? [],
        nextStep:      (json['next_suggestion'] ?? json['next_step']) as String?,
      );
}

// ─────────────────────────────────────────────
// CANDIDATE CARD  (discovery feed item)
// ─────────────────────────────────────────────

class CandidateCard {
  const CandidateCard({
    required this.profile,
    required this.compatibilityScore,
    this.compatibilityBreakdown,
    this.hasAiScore = false,
  });

  final UserProfile          profile;
  final double               compatibilityScore;
  final Map<String, dynamic>? compatibilityBreakdown;
  final bool                 hasAiScore;

  factory CandidateCard.fromJson(Map<String, dynamic> json) => CandidateCard(
    profile:              UserProfile.fromJson(
        json['profile'] as Map<String, dynamic>),
    compatibilityScore:   (json['compatibility_score'] as num?)?.toDouble() ?? 0,
    compatibilityBreakdown: json['compatibility_breakdown'] as Map<String, dynamic>?,
    hasAiScore:           json['has_ai_scoring'] as bool? ?? false,
  );
}

// ─────────────────────────────────────────────
// INTEREST REQUEST
// ─────────────────────────────────────────────

class ExpressInterestRequest {
  const ExpressInterestRequest({
    required this.receiverId,
    required this.message,
  });

  final String receiverId;
  final String message;

  Map<String, dynamic> toJson() => {
    'receiver_id': receiverId,
    'message':     message,
  };
}
