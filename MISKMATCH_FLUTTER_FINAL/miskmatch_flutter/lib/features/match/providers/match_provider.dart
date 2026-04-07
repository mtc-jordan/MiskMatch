import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/match_models.dart';
import '../data/match_repository.dart';
import 'package:miskmatch/shared/models/api_response.dart';

// ─────────────────────────────────────────────
// MATCHES LIST STATE
// ─────────────────────────────────────────────

class MatchListState {
  const MatchListState({
    this.matches    = const [],
    this.isLoading  = false,
    this.error,
  });
  final List<Match> matches;
  final bool        isLoading;
  final AppError?   error;

  List<Match> get activeMatches   => matches.where((m) => m.status.isActive).toList();
  List<Match> get pendingMatches  => matches.where((m) => m.status.needsWali).toList();
  int         get totalUnread     => matches.fold(0, (s, m) => s + m.unreadCount);

  MatchListState copyWith({
    List<Match>? matches, bool? isLoading, AppError? error,
  }) => MatchListState(
    matches:   matches   ?? this.matches,
    isLoading: isLoading ?? this.isLoading,
    error:     error,
  );
}

class MatchListNotifier extends StateNotifier<MatchListState> {
  MatchListNotifier(this._repo) : super(const MatchListState());

  final MatchRepository _repo;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repo.getMatches();
    state = switch (result) {
      ApiSuccess(data: final matches) => state.copyWith(
          matches: matches, isLoading: false),
      ApiError(error: final e) => state.copyWith(isLoading: false, error: e),
    };
  }

  void markRead(String matchId) {
    state = state.copyWith(
      matches: state.matches.map((m) {
        if (m.id == matchId) {
          return Match.fromJson({
            ...m.toJsonPartial(),
            'unread_count': 0,
          });
        }
        return m;
      }).toList(),
    );
  }
}

extension on Match {
  Map<String, dynamic> toJsonPartial() => {
    'id':           id,
    'sender_id':    senderId,
    'receiver_id':  receiverId,
    'status':       status.name,
    'created_at':   createdAt.toIso8601String(),
    'unread_count': unreadCount,
    'match_day':    matchDay,
  };
}

final matchListProvider =
    StateNotifierProvider<MatchListNotifier, MatchListState>((ref) {
  return MatchListNotifier(ref.watch(matchRepositoryProvider));
});

// ─────────────────────────────────────────────
// SINGLE MATCH  (detail)
// ─────────────────────────────────────────────

final matchDetailProvider =
    FutureProvider.family.autoDispose<Match, String>((ref, matchId) async {
  final repo   = ref.watch(matchRepositoryProvider);
  final result = await repo.getMatch(matchId);
  return switch (result) {
    ApiSuccess(data: final m) => m,
    ApiError(error: final e)  => throw e.message,
  };
});

// ─────────────────────────────────────────────
// MATCH RESPOND
// ─────────────────────────────────────────────

final matchRespondProvider =
    StateNotifierProvider.autoDispose<_RespondNotifier, AsyncValue<String>>(
        (ref) => _RespondNotifier(ref.watch(matchRepositoryProvider)));

class _RespondNotifier extends StateNotifier<AsyncValue<String>> {
  _RespondNotifier(this._repo) : super(const AsyncValue.data(''));
  final MatchRepository _repo;

  Future<bool> respond(String matchId, bool accept, {String? response}) async {
    state = const AsyncValue.loading();
    final result = await _repo.respond(
        matchId: matchId, accept: accept, response: response);
    return switch (result) {
      ApiSuccess(data: final msg) => () {
          state = AsyncValue.data(msg);
          return true;
        }(),
      ApiError(error: final e) => () {
          state = AsyncValue.error(e.message, StackTrace.current);
          return false;
        }(),
    };
  }
}
