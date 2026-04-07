import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/game_models.dart';
import '../data/game_repository.dart';
import 'package:miskmatch/shared/models/api_response.dart';

// ─────────────────────────────────────────────
// CATALOGUE PROVIDER
// ─────────────────────────────────────────────

final gameCatalogueProvider =
    FutureProvider.family.autoDispose<GameCatalogue, String>((ref, matchId) async {
  final repo   = ref.watch(gameRepositoryProvider);
  final result = await repo.getCatalogue(matchId);
  return switch (result) {
    ApiSuccess(data: final c) => c,
    ApiError(error: final e)  => throw e.message,
  };
});

// ─────────────────────────────────────────────
// ACTIVE GAME STATE
// ─────────────────────────────────────────────

class GamePlayState {
  const GamePlayState({
    this.gameState,
    this.isLoading      = false,
    this.isSubmitting   = false,
    this.error,
    this.lastResult,
    this.showReveal     = false,  // real-time reveal animation
    this.waitingPartner = false,  // submitted, waiting for other
  });

  final GameState?    gameState;
  final bool          isLoading;
  final bool          isSubmitting;
  final AppError?     error;
  final TurnResult?   lastResult;
  final bool          showReveal;
  final bool          waitingPartner;

  GamePlayState copyWith({
    GameState?   gameState,
    bool?        isLoading,
    bool?        isSubmitting,
    AppError?    error,
    TurnResult?  lastResult,
    bool?        showReveal,
    bool?        waitingPartner,
    bool         clearError = false,
  }) => GamePlayState(
    gameState:      gameState      ?? this.gameState,
    isLoading:      isLoading      ?? this.isLoading,
    isSubmitting:   isSubmitting   ?? this.isSubmitting,
    error:          clearError     ? null : (error ?? this.error),
    lastResult:     lastResult     ?? this.lastResult,
    showReveal:     showReveal     ?? this.showReveal,
    waitingPartner: waitingPartner ?? this.waitingPartner,
  );
}

class GamePlayNotifier extends StateNotifier<GamePlayState> {
  GamePlayNotifier({
    required this.matchId,
    required this.gameType,
    required GameRepository repo,
  })  : _repo = repo,
        super(const GamePlayState()) {
    load();
  }

  final String         matchId;
  final String         gameType;
  final GameRepository _repo;

  // ── Load / start ──────────────────────────────────────────────────────────
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repo.getGameState(matchId, gameType);
    state = switch (result) {
      ApiSuccess(data: final gs) => state.copyWith(
          gameState: gs, isLoading: false),
      ApiError(error: final e) => state.copyWith(
          isLoading: false, error: e),
    };
  }

  Future<bool> startGame() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repo.startGame(matchId, gameType);
    return switch (result) {
      ApiSuccess(data: final gs) => () {
          state = state.copyWith(gameState: gs, isLoading: false);
          return true;
        }(),
      ApiError(error: final e) => () {
          state = state.copyWith(isLoading: false, error: e);
          return false;
        }(),
    };
  }

  // ── Submit async turn ─────────────────────────────────────────────────────
  Future<TurnResult?> submitTurn(String answer,
      {Map<String, dynamic>? answerData}) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    final result = await _repo.submitTurn(
      matchId:    matchId,
      gameType:   gameType,
      answer:     answer,
      answerData: answerData,
    );
    return switch (result) {
      ApiSuccess(data: final r) => () {
          state = state.copyWith(
            isSubmitting: false,
            lastResult:   r,
          );
          // Refresh game state after submission
          load();
          return r;
        }(),
      ApiError(error: final e) => () {
          state = state.copyWith(isSubmitting: false, error: e);
          return null;
        }(),
    };
  }

  // ── Submit real-time answer ───────────────────────────────────────────────
  Future<TurnResult?> submitRealtime(
      String questionId, String answer) async {
    state = state.copyWith(
      isSubmitting:   true,
      waitingPartner: true,
      clearError:     true,
    );
    final result = await _repo.submitRealtime(
      matchId:    matchId,
      gameType:   gameType,
      questionId: questionId,
      answer:     answer,
    );
    return switch (result) {
      ApiSuccess(data: final r) => () {
          state = state.copyWith(
            isSubmitting:   false,
            waitingPartner: !r.bothAnswered,
            lastResult:     r,
            showReveal:     r.bothAnswered,
          );
          if (r.bothAnswered) load();
          return r;
        }(),
      ApiError(error: final e) => () {
          state = state.copyWith(
            isSubmitting: false, waitingPartner: false, error: e);
          return null;
        }(),
    };
  }

  void dismissReveal() =>
      state = state.copyWith(showReveal: false);

  // ── Time Capsule ──────────────────────────────────────────────────────────
  Future<bool> sealCapsule() async {
    state = state.copyWith(isSubmitting: true);
    final result = await _repo.sealCapsule(matchId);
    state = state.copyWith(isSubmitting: false);
    if (result is ApiSuccess) { load(); return true; }
    return false;
  }

  Future<Map<String, dynamic>?> openCapsule() async {
    state = state.copyWith(isSubmitting: true);
    final result = await _repo.openCapsule(matchId);
    state = state.copyWith(isSubmitting: false);
    if (result is ApiSuccess<Map<String, dynamic>>) {
      load();
      return result.data;
    }
    return null;
  }
}

final gamePlayProvider = StateNotifierProvider.family
    .autoDispose<GamePlayNotifier, GamePlayState, ({String matchId, String gameType})>(
    (ref, args) {
  return GamePlayNotifier(
    matchId:  args.matchId,
    gameType: args.gameType,
    repo:     ref.watch(gameRepositoryProvider),
  );
});

// ─────────────────────────────────────────────
// MEMORY TIMELINE PROVIDER
// ─────────────────────────────────────────────

final memoryTimelineProvider =
    FutureProvider.family.autoDispose<MemoryTimeline, String>((ref, matchId) async {
  final repo   = ref.watch(gameRepositoryProvider);
  final result = await repo.getMemoryTimeline(matchId);
  return switch (result) {
    ApiSuccess(data: final t) => t,
    ApiError(error: final e)  => throw e.message,
  };
});
