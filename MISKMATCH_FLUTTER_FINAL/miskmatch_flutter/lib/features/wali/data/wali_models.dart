/// MiskMatch — Wali Portal Domain Models
/// All guardian-related types, mirroring the backend wali endpoints.

import 'package:miskmatch/features/profile/data/profile_models.dart';

// ─────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────

enum WaliRelationship {
  father, brother, uncle, grandfather,
  maleRelative, imam, trustedMaleGuardian;

  String get label => switch (this) {
    WaliRelationship.father             => 'Father',
    WaliRelationship.brother            => 'Brother',
    WaliRelationship.uncle              => 'Uncle',
    WaliRelationship.grandfather        => 'Grandfather',
    WaliRelationship.maleRelative       => 'Male Relative',
    WaliRelationship.imam               => 'Imam',
    WaliRelationship.trustedMaleGuardian=> 'Trusted Guardian',
  };

  String get labelAr => switch (this) {
    WaliRelationship.father             => 'والد',
    WaliRelationship.brother            => 'أخ',
    WaliRelationship.uncle              => 'عم',
    WaliRelationship.grandfather        => 'جد',
    WaliRelationship.maleRelative       => 'قريب',
    WaliRelationship.imam               => 'إمام',
    WaliRelationship.trustedMaleGuardian=> 'وليّ',
  };

  static WaliRelationship fromValue(String v) {
    const map = {
      'father':               WaliRelationship.father,
      'brother':              WaliRelationship.brother,
      'uncle':                WaliRelationship.uncle,
      'grandfather':          WaliRelationship.grandfather,
      'male_relative':        WaliRelationship.maleRelative,
      'imam':                 WaliRelationship.imam,
      'trusted_male_guardian':WaliRelationship.trustedMaleGuardian,
    };
    return map[v] ?? WaliRelationship.trustedMaleGuardian;
  }
}

enum WaliDecision { pending, approved, declined }

// ─────────────────────────────────────────────
// WALI STATUS  (my guardian info)
// ─────────────────────────────────────────────

class WaliStatus {
  const WaliStatus({
    required this.hasWali,
    this.waliId,
    this.waliName,
    this.waliPhone,
    this.relationship,
    this.accepted      = false,
    this.acceptedAt,
    this.permissions   = const WaliPermissions(),
  });

  final bool             hasWali;
  final String?          waliId;
  final String?          waliName;
  final String?          waliPhone;
  final WaliRelationship? relationship;
  final bool             accepted;
  final DateTime?        acceptedAt;
  final WaliPermissions  permissions;

  factory WaliStatus.fromJson(Map<String, dynamic> json) => WaliStatus(
    hasWali:      json['has_wali']   as bool? ?? false,
    waliId:       json['wali_id']    as String?,
    waliName:     json['wali_name']  as String?,
    waliPhone:    json['wali_phone'] as String?,
    relationship: json['relationship'] != null
        ? WaliRelationship.fromValue(json['relationship'] as String)
        : null,
    accepted:     json['accepted']   as bool? ?? false,
    acceptedAt:   json['accepted_at'] != null
        ? DateTime.parse(json['accepted_at'] as String)
        : null,
    permissions:  json['permissions'] != null
        ? WaliPermissions.fromJson(json['permissions'] as Map<String, dynamic>)
        : const WaliPermissions(),
  );
}

// ─────────────────────────────────────────────
// WALI PERMISSIONS
// ─────────────────────────────────────────────

class WaliPermissions {
  const WaliPermissions({
    this.canReadMessages = false,
    this.mustApproveMatches = true,
    this.receivesNotifications = true,
    this.canJoinCalls = true,
  });

  final bool canReadMessages;
  final bool mustApproveMatches;
  final bool receivesNotifications;
  final bool canJoinCalls;

  factory WaliPermissions.fromJson(Map<String, dynamic> json) =>
      WaliPermissions(
        canReadMessages:       json['can_read_messages']      as bool? ?? false,
        mustApproveMatches:    json['must_approve_matches']   as bool? ?? true,
        receivesNotifications: json['receives_notifications'] as bool? ?? true,
        canJoinCalls:          json['can_join_calls']         as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
    'can_read_messages':       canReadMessages,
    'must_approve_matches':    mustApproveMatches,
    'receives_notifications':  receivesNotifications,
    'can_join_calls':          canJoinCalls,
  };

  WaliPermissions copyWith({
    bool? canReadMessages, bool? mustApproveMatches,
    bool? receivesNotifications, bool? canJoinCalls,
  }) => WaliPermissions(
    canReadMessages:       canReadMessages       ?? this.canReadMessages,
    mustApproveMatches:    mustApproveMatches    ?? this.mustApproveMatches,
    receivesNotifications: receivesNotifications ?? this.receivesNotifications,
    canJoinCalls:          canJoinCalls          ?? this.canJoinCalls,
  );
}

// ─────────────────────────────────────────────
// WARD  (person under this wali's guardianship)
// ─────────────────────────────────────────────

class Ward {
  const Ward({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.relationship,
    required this.permissions,
    this.profile,
    this.pendingDecisions = 0,
    this.activeMatches    = 0,
    this.joinedAt,
  });

  final String           userId;
  final String           firstName;
  final String           lastName;
  final WaliRelationship relationship;
  final WaliPermissions  permissions;
  final UserProfile?     profile;
  final int              pendingDecisions;
  final int              activeMatches;
  final DateTime?        joinedAt;

  String get displayName => '$firstName ${lastName.isNotEmpty ? "${lastName[0]}." : ""}';

  factory Ward.fromJson(Map<String, dynamic> json) => Ward(
    userId:       json['user_id']     as String,
    firstName:    json['first_name']  as String,
    lastName:     json['last_name']   as String? ?? '',
    relationship: WaliRelationship.fromValue(
        json['relationship'] as String? ?? 'trusted_male_guardian'),
    permissions:  json['permissions'] != null
        ? WaliPermissions.fromJson(json['permissions'] as Map<String, dynamic>)
        : const WaliPermissions(),
    profile: json['profile'] != null
        ? UserProfile.fromJson(json['profile'] as Map<String, dynamic>)
        : null,
    pendingDecisions: json['pending_decisions'] as int? ?? 0,
    activeMatches:    json['active_matches']    as int? ?? 0,
    joinedAt: json['joined_at'] != null
        ? DateTime.parse(json['joined_at'] as String)
        : null,
  );
}

// ─────────────────────────────────────────────
// WALI DASHBOARD
// ─────────────────────────────────────────────

class WaliDashboard {
  const WaliDashboard({
    required this.wards,
    required this.pendingCount,
    required this.totalMatches,
    required this.pendingDecisions,
    required this.flaggedMessages,
  });

  final List<Ward>         wards;
  final int                pendingCount;
  final int                totalMatches;
  final List<WaliMatchDecision> pendingDecisions;
  final List<FlaggedMessage>    flaggedMessages;

  bool get hasPending  => pendingDecisions.isNotEmpty;
  bool get hasFlagged  => flaggedMessages.isNotEmpty;

  factory WaliDashboard.fromJson(Map<String, dynamic> json) => WaliDashboard(
    wards:  (json['wards'] as List<dynamic>? ?? [])
        .map((e) => Ward.fromJson(e as Map<String, dynamic>))
        .toList(),
    pendingCount:  json['pending_count']  as int? ?? 0,
    totalMatches:  json['total_matches']  as int? ?? 0,
    pendingDecisions: (json['pending_decisions'] as List<dynamic>? ?? [])
        .map((e) => WaliMatchDecision.fromJson(e as Map<String, dynamic>))
        .toList(),
    flaggedMessages: (json['flagged_messages'] as List<dynamic>? ?? [])
        .map((e) => FlaggedMessage.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

// ─────────────────────────────────────────────
// WALI MATCH DECISION  (pending approval)
// ─────────────────────────────────────────────

class WaliMatchDecision {
  const WaliMatchDecision({
    required this.matchId,
    required this.wardId,
    required this.wardName,
    required this.candidateId,
    required this.candidateName,
    required this.candidateAge,
    required this.senderMessage,
    required this.compatibilityScore,
    required this.receivedAt,
    this.candidateCity,
    this.candidateMadhab,
    this.candidatePrayerFreq,
    this.candidateBio,
    this.candidateTrustScore = 0,
    this.candidateMosqueVerified = false,
    this.decision = WaliDecision.pending,
  });

  final String         matchId;
  final String         wardId;
  final String         wardName;
  final String         candidateId;
  final String         candidateName;
  final int?           candidateAge;
  final String         senderMessage;
  final double         compatibilityScore;
  final DateTime       receivedAt;
  final String?        candidateCity;
  final String?        candidateMadhab;
  final String?        candidatePrayerFreq;
  final String?        candidateBio;
  final int            candidateTrustScore;
  final bool           candidateMosqueVerified;
  final WaliDecision   decision;

  bool get isPending   => decision == WaliDecision.pending;

  factory WaliMatchDecision.fromJson(Map<String, dynamic> json) =>
      WaliMatchDecision(
        matchId:           json['match_id']            as String,
        wardId:            json['ward_id']             as String,
        wardName:          json['ward_name']           as String? ?? '',
        candidateId:       json['candidate_id']        as String,
        candidateName:     json['candidate_name']      as String? ?? '',
        candidateAge:      json['candidate_age']       as int?,
        senderMessage:     json['sender_message']      as String? ?? '',
        compatibilityScore:(json['compatibility_score'] as num?)?.toDouble() ?? 0,
        receivedAt:        DateTime.parse(json['received_at'] as String),
        candidateCity:     json['candidate_city']      as String?,
        candidateMadhab:   json['candidate_madhab']    as String?,
        candidatePrayerFreq:json['candidate_prayer_freq']as String?,
        candidateBio:      json['candidate_bio']       as String?,
        candidateTrustScore:json['candidate_trust_score']as int? ?? 0,
        candidateMosqueVerified:
            json['candidate_mosque_verified'] as bool? ?? false,
        decision:          _parseDecision(json['decision'] as String?),
      );

  static WaliDecision _parseDecision(String? v) => switch (v) {
    'approved' => WaliDecision.approved,
    'declined' => WaliDecision.declined,
    _          => WaliDecision.pending,
  };
}

// ─────────────────────────────────────────────
// FLAGGED MESSAGE
// ─────────────────────────────────────────────

class FlaggedMessage {
  const FlaggedMessage({
    required this.messageId,
    required this.matchId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.flaggedAt,
    required this.moderationReason,
    this.wardId,
    this.wardName,
    this.reviewed = false,
  });

  final String   messageId;
  final String   matchId;
  final String   senderId;
  final String   senderName;
  final String   content;
  final DateTime flaggedAt;
  final String   moderationReason;
  final String?  wardId;
  final String?  wardName;
  final bool     reviewed;

  factory FlaggedMessage.fromJson(Map<String, dynamic> json) =>
      FlaggedMessage(
        messageId:        json['message_id']       as String,
        matchId:          json['match_id']         as String,
        senderId:         json['sender_id']        as String,
        senderName:       json['sender_name']      as String? ?? '',
        content:          json['content']          as String? ?? '',
        flaggedAt:        DateTime.parse(json['flagged_at'] as String),
        moderationReason: json['moderation_reason']as String? ?? '',
        wardId:           json['ward_id']          as String?,
        wardName:         json['ward_name']        as String?,
        reviewed:         json['reviewed']         as bool? ?? false,
      );
}

// ─────────────────────────────────────────────
// WALI CONVERSATION SUMMARY
// ─────────────────────────────────────────────

class WaliConversation {
  const WaliConversation({
    required this.matchId,
    required this.wardName,
    required this.candidateName,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.totalMessages,
    this.unreadCount = 0,
  });

  final String   matchId;
  final String   wardName;
  final String   candidateName;
  final String   lastMessage;
  final DateTime lastMessageAt;
  final int      totalMessages;
  final int      unreadCount;

  factory WaliConversation.fromJson(Map<String, dynamic> json) =>
      WaliConversation(
        matchId:         json['match_id']          as String,
        wardName:        json['ward_name']         as String? ?? '',
        candidateName:   json['candidate_name']    as String? ?? '',
        lastMessage:     json['last_message']      as String? ?? '',
        lastMessageAt:   DateTime.parse(json['last_message_at'] as String),
        totalMessages:   json['total_messages']    as int? ?? 0,
        unreadCount:     json['unread_count']      as int? ?? 0,
      );
}

// ─────────────────────────────────────────────
// REQUEST MODELS
// ─────────────────────────────────────────────

class WaliSetupRequest {
  const WaliSetupRequest({
    required this.waliName,
    required this.waliPhone,
    required this.relationship,
    this.permissions = const WaliPermissions(),
  });

  final String           waliName;
  final String           waliPhone;
  final WaliRelationship relationship;
  final WaliPermissions  permissions;

  Map<String, dynamic> toJson() => {
    'wali_name':     waliName,
    'wali_phone':    waliPhone,
    'relationship':  _relValue(relationship),
    'permissions':   permissions.toJson(),
  };

  static String _relValue(WaliRelationship r) => switch (r) {
    WaliRelationship.father              => 'father',
    WaliRelationship.brother             => 'brother',
    WaliRelationship.uncle               => 'uncle',
    WaliRelationship.grandfather         => 'grandfather',
    WaliRelationship.maleRelative        => 'male_relative',
    WaliRelationship.imam                => 'imam',
    WaliRelationship.trustedMaleGuardian => 'trusted_male_guardian',
  };
}

class WaliDecisionRequest {
  const WaliDecisionRequest({
    required this.matchId,
    required this.approved,
    this.notes,
  });

  final String  matchId;
  final bool    approved;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'approved': approved,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
  };
}
