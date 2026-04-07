import 'package:miskmatch/features/profile/data/profile_models.dart';

/// MiskMatch — Match & Message Domain Models

// ─────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────

enum MatchStatus {
  pending,
  mutual,
  approved,
  active,
  nikah,
  closed,
  blocked;

  static MatchStatus fromValue(String v) =>
      MatchStatus.values.firstWhere((e) => e.name == v,
          orElse: () => MatchStatus.closed);

  String get label => switch (this) {
        MatchStatus.pending  => 'Interest sent',
        MatchStatus.mutual   => 'Mutual — awaiting families',
        MatchStatus.approved => 'Families reviewing',
        MatchStatus.active   => 'Active',
        MatchStatus.nikah    => 'Nikah 🌹',
        MatchStatus.closed   => 'Closed',
        MatchStatus.blocked  => 'Blocked',
      };

  bool get isActive     => this == MatchStatus.active;
  bool get needsWali    => this == MatchStatus.mutual ||
                           this == MatchStatus.approved;
  bool get canChat      => this == MatchStatus.active;
  bool get canPlayGames => this == MatchStatus.active;
}

enum MessageStatus {
  sent, delivered, read, flagged;

  static MessageStatus fromValue(String v) =>
      MessageStatus.values.firstWhere((e) => e.name == v,
          orElse: () => MessageStatus.sent);
}

// ─────────────────────────────────────────────
// MATCH
// ─────────────────────────────────────────────

class Match {
  const Match({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    this.senderProfile,
    this.receiverProfile,
    this.senderMessage,
    this.receiverResponse,
    this.senderWaliApproved,
    this.receiverWaliApproved,
    this.senderWaliApprovedAt,
    this.receiverWaliApprovedAt,
    this.compatibilityScore,
    this.compatibilityBreakdown,
    this.becameMutualAt,
    this.nikahDate,
    this.closedReason,
    this.memoryTimeline = const [],
    this.matchDay = 0,
    this.lastMessage,
    this.unreadCount = 0,
  });

  final String     id;
  final String     senderId;
  final String     receiverId;
  final MatchStatus status;
  final DateTime   createdAt;
  final UserProfile? senderProfile;
  final UserProfile? receiverProfile;
  final String?    senderMessage;
  final String?    receiverResponse;
  final bool?      senderWaliApproved;
  final bool?      receiverWaliApproved;
  final DateTime?  senderWaliApprovedAt;
  final DateTime?  receiverWaliApprovedAt;
  final double?    compatibilityScore;
  final Map<String, dynamic>? compatibilityBreakdown;
  final DateTime?  becameMutualAt;
  final DateTime?  nikahDate;
  final String?    closedReason;
  final List<Map<String, dynamic>> memoryTimeline;
  final int        matchDay;
  final Message?   lastMessage;
  final int        unreadCount;

  /// The OTHER person in the match (from current user's perspective)
  UserProfile? otherProfile(String myUserId) =>
      senderId == myUserId ? receiverProfile : senderProfile;

  String otherId(String myUserId) =>
      senderId == myUserId ? receiverId : senderId;

  bool myWaliApproved(String myUserId) =>
      senderId == myUserId
          ? senderWaliApproved ?? false
          : receiverWaliApproved ?? false;

  bool theirWaliApproved(String myUserId) =>
      senderId == myUserId
          ? receiverWaliApproved ?? false
          : senderWaliApproved ?? false;

  bool get bothWalisApproved =>
      senderWaliApproved == true && receiverWaliApproved == true;

  factory Match.fromJson(Map<String, dynamic> json) => Match(
    id:          json['id']           as String,
    senderId:    json['sender_id']    as String,
    receiverId:  json['receiver_id']  as String,
    status:      MatchStatus.fromValue(json['status'] as String? ?? 'closed'),
    createdAt:   DateTime.parse(json['created_at'] as String),
    senderProfile: json['sender_profile'] != null
        ? UserProfile.fromJson(json['sender_profile'] as Map<String, dynamic>)
        : null,
    receiverProfile: json['receiver_profile'] != null
        ? UserProfile.fromJson(json['receiver_profile'] as Map<String, dynamic>)
        : null,
    senderMessage:         json['sender_message']          as String?,
    receiverResponse:      json['receiver_response']       as String?,
    senderWaliApproved:    json['sender_wali_approved']    as bool?,
    receiverWaliApproved:  json['receiver_wali_approved']  as bool?,
    compatibilityScore:
        (json['compatibility_score'] as num?)?.toDouble(),
    compatibilityBreakdown:
        json['compatibility_breakdown'] as Map<String, dynamic>?,
    becameMutualAt: json['became_mutual_at'] != null
        ? DateTime.parse(json['became_mutual_at'] as String)
        : null,
    nikahDate:   json['nikah_date'] != null
        ? DateTime.parse(json['nikah_date'] as String)
        : null,
    closedReason:json['closed_reason'] as String?,
    memoryTimeline: (json['memory_timeline'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [],
    matchDay:    json['match_day'] as int? ?? 0,
    lastMessage: json['last_message'] != null
        ? Message.fromJson(json['last_message'] as Map<String, dynamic>)
        : null,
    unreadCount: json['unread_count'] as int? ?? 0,
  );
}

// ─────────────────────────────────────────────
// MESSAGE
// ─────────────────────────────────────────────

class Message {
  const Message({
    required this.id,
    required this.matchId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.contentType = 'text',
    this.mediaUrl,
    this.status      = MessageStatus.sent,
    this.senderName,
    this.moderationPassed,
  });

  final String        id;
  final String        matchId;
  final String        senderId;
  final String        content;
  final String        contentType; // text | audio | image
  final String?       mediaUrl;
  final MessageStatus status;
  final DateTime      createdAt;
  final String?       senderName;
  final bool?         moderationPassed;

  bool get isAudio    => contentType == 'audio';
  bool get isImage    => contentType == 'image';
  bool get isFlagged  => status == MessageStatus.flagged;

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id:          json['id']         as String,
    matchId:     json['match_id']   as String,
    senderId:    json['sender_id']  as String,
    content:     json['content']    as String,
    contentType: json['content_type'] as String? ?? 'text',
    mediaUrl:    json['media_url']  as String?,
    status:      MessageStatus.fromValue(json['status'] as String? ?? 'sent'),
    createdAt:   DateTime.parse(json['created_at'] as String),
    senderName:  json['sender_name'] as String?,
    moderationPassed: json['moderation_passed'] as bool?,
  );

  Map<String, dynamic> toJson() => {
    'match_id':     matchId,
    'content':      content,
    'content_type': contentType,
    if (mediaUrl != null) 'media_url': mediaUrl,
  };
}

// ─────────────────────────────────────────────
// MESSAGE GROUP  (grouped by date for chat UI)
// ─────────────────────────────────────────────

class MessageGroup {
  const MessageGroup({required this.date, required this.messages});
  final DateTime       date;
  final List<Message>  messages;
}

List<MessageGroup> groupMessagesByDate(List<Message> messages) {
  final groups = <String, List<Message>>{};
  for (final msg in messages) {
    final key = '${msg.createdAt.year}-${msg.createdAt.month}-${msg.createdAt.day}';
    (groups[key] ??= []).add(msg);
  }
  return groups.entries
      .map((e) {
        final parts  = e.key.split('-').map(int.parse).toList();
        return MessageGroup(
          date:     DateTime(parts[0], parts[1], parts[2]),
          messages: e.value,
        );
      })
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
}

// ─────────────────────────────────────────────
// SEND MESSAGE REQUEST
// ─────────────────────────────────────────────

class SendMessageRequest {
  const SendMessageRequest({
    required this.matchId,
    required this.content,
    this.contentType = 'text',
    this.mediaUrl,
    this.clientId,
  });

  final String  matchId;
  final String  content;
  final String  contentType;
  final String? mediaUrl;
  final String? clientId; // idempotency key

  Map<String, dynamic> toJson() => {
    'match_id':     matchId,
    'content':      content,
    'content_type': contentType,
    if (mediaUrl  != null) 'media_url': mediaUrl,
    if (clientId  != null) 'client_id': clientId,
  };
}

// ─────────────────────────────────────────────
// WALI DECISION STATUS
// ─────────────────────────────────────────────

class WaliDecisionStatus {
  const WaliDecisionStatus({
    required this.myWaliApproved,
    required this.theirWaliApproved,
    required this.myWaliName,
  });

  final bool?   myWaliApproved;
  final bool?   theirWaliApproved;
  final String? myWaliName;

  bool get bothApproved    => myWaliApproved == true && theirWaliApproved == true;
  bool get waitingForMine  => myWaliApproved == null;
  bool get waitingForTheirs=> theirWaliApproved == null;
}

// ─────────────────────────────────────────────
// TYPING EVENT
// ─────────────────────────────────────────────

class TypingEvent {
  const TypingEvent({
    required this.userId,
    required this.userName,
    required this.matchId,
    required this.isTyping,
  });

  final String userId;
  final String userName;
  final String matchId;
  final bool   isTyping;

  factory TypingEvent.fromJson(Map<String, dynamic> json) => TypingEvent(
    userId:   json['user_id']   as String,
    userName: json['user_name'] as String? ?? '',
    matchId:  json['match_id']  as String,
    isTyping: json['typing']    as bool? ?? false,
  );
}
