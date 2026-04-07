/// MiskMatch — Call Domain Models

enum CallType {
  audio, video, videoChaperoned;

  String get value => switch (this) {
    CallType.audio           => 'audio',
    CallType.video           => 'video',
    CallType.videoChaperoned => 'video_chaperoned',
  };

  String get label => switch (this) {
    CallType.audio           => 'Audio Call',
    CallType.video           => 'Video Call',
    CallType.videoChaperoned => 'Chaperoned Call',
  };

  String get emoji => switch (this) {
    CallType.audio           => '📞',
    CallType.video           => '📹',
    CallType.videoChaperoned => '🛡️',
  };

  bool get isVideo => this != CallType.audio;
  bool get isChaperoned => this == CallType.videoChaperoned;

  static CallType fromValue(String v) => switch (v) {
    'audio'            => CallType.audio,
    'video'            => CallType.video,
    'video_chaperoned' => CallType.videoChaperoned,
    _                  => CallType.videoChaperoned,
  };
}

enum CallStatus {
  scheduled, ringing, active, ended, missed;

  static CallStatus fromValue(String v) => switch (v) {
    'scheduled' => CallStatus.scheduled,
    'ringing'   => CallStatus.ringing,
    'active'    => CallStatus.active,
    'ended'     => CallStatus.ended,
    'missed'    => CallStatus.missed,
    _           => CallStatus.ringing,
  };
}

// ─────────────────────────────────────────────
// AGORA TOKEN
// ─────────────────────────────────────────────

class AgoraToken {
  const AgoraToken({
    required this.callId,
    required this.channelName,
    required this.agoraToken,
    required this.uid,
    required this.appId,
    required this.expiresAt,
    required this.role,
  });

  final String   callId;
  final String   channelName;
  final String   agoraToken;
  final int      uid;
  final String   appId;
  final DateTime expiresAt;
  final String   role;        // "publisher" | "subscriber"

  bool get isPublisher => role == 'publisher';

  factory AgoraToken.fromJson(Map<String, dynamic> json) => AgoraToken(
    callId:      json['call_id']      as String,
    channelName: json['channel_name'] as String,
    agoraToken:  json['agora_token']  as String,
    uid:         json['uid']          as int,
    appId:       json['app_id']       as String,
    expiresAt:   DateTime.parse(json['expires_at'] as String),
    role:        json['role']         as String? ?? 'publisher',
  );
}

// ─────────────────────────────────────────────
// CALL MODEL
// ─────────────────────────────────────────────

class CallModel {
  const CallModel({
    required this.id,
    required this.matchId,
    required this.initiatorId,
    required this.callType,
    required this.channelName,
    required this.status,
    this.waliInvited     = true,
    this.waliJoined      = false,
    this.waliApproved,
    this.scheduledAt,
    this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.token,
  });

  final String      id;
  final String      matchId;
  final String      initiatorId;
  final CallType    callType;
  final String      channelName;
  final CallStatus  status;
  final bool        waliInvited;
  final bool        waliJoined;
  final bool?       waliApproved;
  final DateTime?   scheduledAt;
  final DateTime?   startedAt;
  final DateTime?   endedAt;
  final int?        durationSeconds;
  final AgoraToken? token;

  bool get isActive    => status == CallStatus.active;
  bool get isRinging   => status == CallStatus.ringing;
  bool get isScheduled => status == CallStatus.scheduled;
  bool get hasToken    => token != null;

  String get formattedDuration {
    if (durationSeconds == null || durationSeconds == 0) return '0:00';
    final m = durationSeconds! ~/ 60;
    final s = (durationSeconds! % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  factory CallModel.fromJson(Map<String, dynamic> json) => CallModel(
    id:              json['id']              as String,
    matchId:         json['match_id']        as String,
    initiatorId:     json['initiator_id']    as String,
    callType:        CallType.fromValue(json['call_type']  as String? ?? ''),
    channelName:     json['agora_channel']   as String,
    status:          CallStatus.fromValue(json['status']   as String? ?? ''),
    waliInvited:     json['wali_invited']    as bool? ?? true,
    waliJoined:      json['wali_joined']     as bool? ?? false,
    waliApproved:    json['wali_approved']   as bool?,
    scheduledAt:     json['scheduled_at'] != null
        ? DateTime.parse(json['scheduled_at'] as String) : null,
    startedAt:       json['started_at'] != null
        ? DateTime.parse(json['started_at'] as String) : null,
    endedAt:         json['ended_at'] != null
        ? DateTime.parse(json['ended_at'] as String) : null,
    durationSeconds: json['duration_seconds'] as int?,
    token: json['token'] != null
        ? AgoraToken.fromJson(json['token'] as Map<String, dynamic>) : null,
  );
}

// ─────────────────────────────────────────────
// PARTICIPANT MODEL  (in-call view)
// ─────────────────────────────────────────────

class CallParticipant {
  const CallParticipant({
    required this.uid,
    required this.name,
    required this.role,
    this.videoEnabled = true,
    this.audioEnabled = true,
    this.isSpeaking   = false,
  });

  final int    uid;
  final String name;
  final String role;       // "initiator" | "receiver" | "wali"
  final bool   videoEnabled;
  final bool   audioEnabled;
  final bool   isSpeaking;

  bool get isWali      => role == 'wali';
  bool get isPublisher => role != 'wali';

  String get emoji => switch (role) {
    'wali'      => '🛡️',
    'initiator' => '📹',
    'receiver'  => '📹',
    _           => '👤',
  };

  static const uidInitiator = 1001;
  static const uidReceiver  = 1002;
  static const uidWali      = 1003;

  CallParticipant copyWith({bool? videoEnabled, bool? audioEnabled, bool? isSpeaking}) =>
      CallParticipant(
        uid:          uid,
        name:         name,
        role:         role,
        videoEnabled: videoEnabled ?? this.videoEnabled,
        audioEnabled: audioEnabled ?? this.audioEnabled,
        isSpeaking:   isSpeaking   ?? this.isSpeaking,
      );
}

// ─────────────────────────────────────────────
// REQUEST MODELS
// ─────────────────────────────────────────────

class InitiateCallRequest {
  const InitiateCallRequest({
    required this.matchId,
    this.callType        = 'video_chaperoned',
    this.inviteWali      = true,
    this.scheduledAt,
    this.recordingConsent = false,
  });

  final String    matchId;
  final String    callType;
  final bool      inviteWali;
  final DateTime? scheduledAt;
  final bool      recordingConsent;

  Map<String, dynamic> toJson() => {
    'match_id':          matchId,
    'call_type':         callType,
    'invite_wali':       inviteWali,
    'recording_consent': recordingConsent,
    if (scheduledAt != null) 'scheduled_at': scheduledAt!.toIso8601String(),
  };
}
