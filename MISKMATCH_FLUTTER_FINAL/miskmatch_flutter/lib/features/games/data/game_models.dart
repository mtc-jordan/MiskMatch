/// MiskMatch — Game Domain Models
/// Mirrors the backend games engine exactly.

// ─────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────

enum GameCategory {
  getToKnow,
  islamic,
  creative,
  trust,
  waliInclusive;

  String get label => switch (this) {
    GameCategory.getToKnow     => 'Get to Know',
    GameCategory.islamic       => 'Islamic',
    GameCategory.creative      => 'Creative',
    GameCategory.trust         => 'Trust & Values',
    GameCategory.waliInclusive => 'Family Inclusive',
  };

  String get labelAr => switch (this) {
    GameCategory.getToKnow     => 'تعارف',
    GameCategory.islamic       => 'إسلامي',
    GameCategory.creative      => 'إبداعي',
    GameCategory.trust         => 'الثقة والقيم',
    GameCategory.waliInclusive => 'مع العائلة',
  };

  static GameCategory fromValue(String v) => switch (v) {
    'get_to_know'    => GameCategory.getToKnow,
    'islamic'        => GameCategory.islamic,
    'creative'       => GameCategory.creative,
    'trust'          => GameCategory.trust,
    'wali_inclusive' => GameCategory.waliInclusive,
    _                => GameCategory.getToKnow,
  };
}

enum GameMode {
  asyncTurn,
  realTime,
  collaborative,
  timerSealed;

  static GameMode fromValue(String v) => switch (v) {
    'async_turn'    => GameMode.asyncTurn,
    'real_time'     => GameMode.realTime,
    'collaborative' => GameMode.collaborative,
    'timer_sealed'  => GameMode.timerSealed,
    _               => GameMode.asyncTurn,
  };
}

enum GameStatus {
  notStarted,
  inProgress,
  awaitingTurn,
  sealed,
  completed,
  abandoned;

  static GameStatus fromValue(String? v) => switch (v) {
    'not_started'   => GameStatus.notStarted,
    'in_progress'   => GameStatus.inProgress,
    'awaiting_turn' => GameStatus.awaitingTurn,
    'sealed'        => GameStatus.sealed,
    'completed'     => GameStatus.completed,
    'abandoned'     => GameStatus.abandoned,
    _               => GameStatus.notStarted,
  };

  bool get isPlayable => this == GameStatus.inProgress ||
                         this == GameStatus.awaitingTurn;
  bool get isDone     => this == GameStatus.completed;
  bool get isNew      => this == GameStatus.notStarted;
}

// ─────────────────────────────────────────────
// GAME META  (catalogue entry)
// ─────────────────────────────────────────────

class GameMeta {
  const GameMeta({
    required this.type,
    required this.name,
    required this.nameAr,
    required this.description,
    required this.category,
    required this.mode,
    required this.icon,
    required this.unlockDay,
    required this.totalTurns,
    required this.unlocked,
    required this.daysToUnlock,
    required this.status,
    required this.progress,
    required this.myTurn,
    this.sealed    = false,
    this.opensAt,
    this.canOpen   = false,
  });

  final String     type;
  final String     name;
  final String     nameAr;
  final String     description;
  final GameCategory category;
  final GameMode   mode;
  final String     icon;
  final int        unlockDay;
  final int        totalTurns;
  final bool       unlocked;
  final int        daysToUnlock;
  final GameStatus status;
  final String     progress;    // "3/10"
  final bool       myTurn;
  final bool       sealed;
  final DateTime?  opensAt;
  final bool       canOpen;

  int get progressCurrent => int.tryParse(progress.split('/').first) ?? 0;
  double get progressFraction =>
      totalTurns > 0 ? progressCurrent / totalTurns : 0;

  bool get isTimeCapsule => type == 'time_capsule';
  bool get isRealTime    => mode == GameMode.realTime;

  factory GameMeta.fromJson(Map<String, dynamic> json) => GameMeta(
    type:        json['type']           as String,
    name:        json['name']           as String,
    nameAr:      json['name_ar']        as String? ?? '',
    description: json['description']   as String? ?? '',
    category:    GameCategory.fromValue(json['category'] as String? ?? ''),
    mode:        GameMode.fromValue(json['mode']         as String? ?? ''),
    icon:        json['icon']           as String? ?? '🎮',
    unlockDay:   json['unlock_day']     as int? ?? 1,
    totalTurns:  json['total_turns']    as int? ?? 10,
    unlocked:    json['unlocked']       as bool? ?? false,
    daysToUnlock:json['days_to_unlock'] as int? ?? 0,
    status:      GameStatus.fromValue(json['status'] as String?),
    progress:    json['progress']       as String? ?? '0/0',
    myTurn:      json['my_turn']        as bool? ?? false,
    sealed:      json['sealed']         as bool? ?? false,
    opensAt:     json['opens_at'] != null
        ? DateTime.tryParse(json['opens_at'] as String)
        : null,
    canOpen:     json['can_open'] as bool? ?? false,
  );
}

// ─────────────────────────────────────────────
// GAME CATALOGUE RESPONSE
// ─────────────────────────────────────────────

class GameCatalogue {
  const GameCatalogue({
    required this.matchId,
    required this.matchDay,
    required this.totalUnlocked,
    required this.totalGames,
    required this.categories,
    required this.myTurnGames,
  });

  final String                        matchId;
  final int                           matchDay;
  final int                           totalUnlocked;
  final int                           totalGames;
  final Map<String, List<GameMeta>>   categories;
  final List<GameMeta>                myTurnGames;

  List<GameMeta> get allGames =>
      categories.values.expand((g) => g).toList();

  factory GameCatalogue.fromJson(Map<String, dynamic> json) {
    final cats = <String, List<GameMeta>>{};
    final rawCats = json['categories'] as Map<String, dynamic>? ?? {};
    for (final entry in rawCats.entries) {
      cats[entry.key] = (entry.value as List<dynamic>)
          .map((e) => GameMeta.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return GameCatalogue(
      matchId:      json['match_id']      as String,
      matchDay:     json['match_day']     as int? ?? 0,
      totalUnlocked:json['total_unlocked']as int? ?? 0,
      totalGames:   json['total_games']   as int? ?? 17,
      categories:   cats,
      myTurnGames:  (json['my_turn_games'] as List<dynamic>? ?? [])
          .map((e) => GameMeta.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────
// GAME STATE  (detail for playing)
// ─────────────────────────────────────────────

class GameState {
  const GameState({
    required this.gameType,
    required this.name,
    required this.icon,
    required this.status,
    required this.turnNumber,
    required this.totalTurns,
    required this.myTurn,
    this.currentQuestion,
    this.turnsHistory = const [],
    this.scores       = const {},
    this.sealed       = false,
    this.opensAt,
    this.canOpen      = false,
    this.completedAt,
  });

  final String          gameType;
  final String          name;
  final String          icon;
  final GameStatus      status;
  final int             turnNumber;
  final int             totalTurns;
  final bool            myTurn;
  final Map<String, dynamic>? currentQuestion;
  final List<Map<String, dynamic>> turnsHistory;
  final Map<String, dynamic> scores;
  final bool            sealed;
  final DateTime?       opensAt;
  final bool            canOpen;
  final DateTime?       completedAt;

  double get progressFraction =>
      totalTurns > 0 ? turnNumber / totalTurns : 0;

  Duration? get timeUntilOpen {
    if (opensAt == null) return null;
    final diff = opensAt!.difference(DateTime.now().toUtc());
    return diff.isNegative ? Duration.zero : diff;
  }

  factory GameState.fromJson(Map<String, dynamic> json) => GameState(
    gameType:    json['game_type']     as String,
    name:        json['name']          as String? ?? '',
    icon:        json['icon']          as String? ?? '🎮',
    status:      GameStatus.fromValue(json['status'] as String?),
    turnNumber:  json['turn_number']   as int? ?? 0,
    totalTurns:  json['total_turns']   as int? ?? 10,
    myTurn:      json['my_turn']       as bool? ?? false,
    currentQuestion: json['current_question'] as Map<String, dynamic>?,
    turnsHistory:(json['turns_history'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>(),
    scores:      json['scores'] as Map<String, dynamic>? ?? {},
    sealed:      json['sealed']        as bool? ?? false,
    opensAt:     json['opens_at'] != null
        ? DateTime.tryParse(json['opens_at'] as String)
        : null,
    canOpen:     json['can_open']      as bool? ?? false,
    completedAt: json['completed_at'] != null
        ? DateTime.tryParse(json['completed_at'] as String)
        : null,
  );
}

// ─────────────────────────────────────────────
// TURN RESULT
// ─────────────────────────────────────────────

class TurnResult {
  const TurnResult({
    required this.status,
    this.message,
    this.turnNumber,
    this.nextQuestion,
    this.yourAnswer,
    this.progress,
    // Real-time fields
    this.partnerAnswer,
    this.bothAnswered  = false,
    this.reveal        = false,
    this.correctAnswer,
    this.youGotIt,
    this.theyGotIt,
    this.scores,
    this.gameComplete  = false,
  });

  final String  status;       // "turn_submitted" | "completed" | "waiting_for_partner"
  final String? message;
  final int?    turnNumber;
  final Map<String, dynamic>? nextQuestion;
  final String? yourAnswer;
  final String? progress;
  // Real-time reveal
  final String? partnerAnswer;
  final bool    bothAnswered;
  final bool    reveal;
  final String? correctAnswer;
  final bool?   youGotIt;
  final bool?   theyGotIt;
  final Map<String, dynamic>? scores;
  final bool    gameComplete;

  bool get isCompleted => status == 'completed' || gameComplete;
  bool get isWaiting   => status == 'waiting_for_partner';

  factory TurnResult.fromJson(Map<String, dynamic> json) => TurnResult(
    status:        json['status']          as String? ?? '',
    message:       json['message']         as String?,
    turnNumber:    json['turn_number']     as int?,
    nextQuestion:  json['next_question']   as Map<String, dynamic>?,
    yourAnswer:    json['your_answer']     as String?,
    progress:      json['progress']        as String?,
    partnerAnswer: json['partner_answer']  as String?,
    bothAnswered:  json['both_answered']   as bool? ?? false,
    reveal:        json['reveal']          as bool? ?? false,
    correctAnswer: json['correct_answer']  as String?,
    youGotIt:      json['you_got_it']      as bool?,
    theyGotIt:     json['they_got_it']     as bool?,
    scores:        json['scores']          as Map<String, dynamic>?,
    gameComplete:  json['game_complete']   as bool? ?? false,
  );
}

// ─────────────────────────────────────────────
// MEMORY TIMELINE
// ─────────────────────────────────────────────

class MemoryTimeline {
  const MemoryTimeline({
    required this.matchId,
    required this.matchDay,
    required this.totalEvents,
    required this.entries,
    required this.gamesCompleted,
  });

  final String              matchId;
  final int                 matchDay;
  final int                 totalEvents;
  final List<TimelineEntry> entries;
  final int                 gamesCompleted;

  factory MemoryTimeline.fromJson(Map<String, dynamic> json) {
    final tl    = json['timeline'] as List<dynamic>? ?? [];
    final summ  = json['summary']  as Map<String, dynamic>? ?? {};
    return MemoryTimeline(
      matchId:       json['match_id']  as String,
      matchDay:      json['match_day'] as int? ?? 0,
      totalEvents:   json['total_events'] as int? ?? 0,
      entries:       tl.map((e) =>
          TimelineEntry.fromJson(e as Map<String, dynamic>)).toList(),
      gamesCompleted: summ['games_completed'] as int? ?? 0,
    );
  }
}

class TimelineEntry {
  const TimelineEntry({
    required this.type,
    required this.event,
    required this.title,
    required this.titleAr,
    required this.icon,
    this.date,
    this.gameType,
    this.category,
  });

  final String   type;
  final String   event;
  final String   title;
  final String   titleAr;
  final String   icon;
  final DateTime? date;
  final String?  gameType;
  final String?  category;

  bool get isMilestone    => type == 'milestone';
  bool get isGameComplete => type == 'game_completed';

  factory TimelineEntry.fromJson(Map<String, dynamic> json) => TimelineEntry(
    type:     json['type']      as String? ?? '',
    event:    json['event']     as String? ?? '',
    title:    json['title']     as String? ?? '',
    titleAr:  json['title_ar']  as String? ?? '',
    icon:     json['icon']      as String? ?? '🌙',
    date:     json['date'] != null
        ? DateTime.tryParse(json['date'] as String)
        : null,
    gameType: json['game_type'] as String?,
    category: json['category']  as String?,
  );
}
