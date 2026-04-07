import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/wali_models.dart';
import '../data/wali_repository.dart';
import 'package:miskmatch/shared/models/api_response.dart';

// ─────────────────────────────────────────────
// WALI DASHBOARD STATE
// ─────────────────────────────────────────────

class WaliDashboardState {
  const WaliDashboardState({
    this.dashboard,
    this.isLoading      = false,
    this.isDeciding     = false,
    this.error,
    this.successMessage,
    this.decidedIds     = const {},
  });

  final WaliDashboard? dashboard;
  final bool           isLoading;
  final bool           isDeciding;
  final AppError?      error;
  final String?        successMessage;
  final Set<String>    decidedIds; // matchIds already decided this session

  bool get hasPending  =>
      (dashboard?.pendingDecisions.length ?? 0) > 0 &&
      undecidedMatches.isNotEmpty;

  List<WaliMatchDecision> get undecidedMatches =>
      dashboard?.pendingDecisions
          .where((d) => d.isPending && !decidedIds.contains(d.matchId))
          .toList() ??
      [];

  List<FlaggedMessage> get unflaggedMessages =>
      dashboard?.flaggedMessages
          .where((m) => !m.reviewed)
          .toList() ??
      [];

  WaliDashboardState copyWith({
    WaliDashboard? dashboard,
    bool?          isLoading,
    bool?          isDeciding,
    AppError?      error,
    String?        successMessage,
    Set<String>?   decidedIds,
    bool           clearError   = false,
    bool           clearSuccess = false,
  }) => WaliDashboardState(
    dashboard:      dashboard      ?? this.dashboard,
    isLoading:      isLoading      ?? this.isLoading,
    isDeciding:     isDeciding     ?? this.isDeciding,
    error:          clearError     ? null : (error   ?? this.error),
    successMessage: clearSuccess   ? null : (successMessage ?? this.successMessage),
    decidedIds:     decidedIds     ?? this.decidedIds,
  );
}

class WaliDashboardNotifier extends StateNotifier<WaliDashboardState> {
  WaliDashboardNotifier(this._repo) : super(const WaliDashboardState());

  final WaliRepository _repo;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repo.getDashboard();
    state = switch (result) {
      ApiSuccess(data: final d) => state.copyWith(
          dashboard: d, isLoading: false),
      ApiError(error: final e)  => state.copyWith(
          isLoading: false, error: e),
    };
  }

  Future<bool> decide({
    required String matchId,
    required bool   approved,
    String?         notes,
  }) async {
    state = state.copyWith(
        isDeciding: true, clearError: true, clearSuccess: true);

    final result = await _repo.decide(
      WaliDecisionRequest(matchId: matchId, approved: approved, notes: notes),
    );

    return switch (result) {
      ApiSuccess(data: final msg) => () {
          state = state.copyWith(
            isDeciding:     false,
            successMessage: msg,
            decidedIds:     {...state.decidedIds, matchId},
          );
          return true;
        }(),
      ApiError(error: final e) => () {
          state = state.copyWith(isDeciding: false, error: e);
          return false;
        }(),
    };
  }

  void clearSuccess() =>
      state = state.copyWith(clearSuccess: true);

  void clearError() =>
      state = state.copyWith(clearError: true);
}

final waliDashboardProvider =
    StateNotifierProvider<WaliDashboardNotifier, WaliDashboardState>((ref) {
  return WaliDashboardNotifier(ref.watch(waliRepositoryProvider));
});

// ─────────────────────────────────────────────
// WALI STATUS  (for the ward's own view)
// ─────────────────────────────────────────────

final waliStatusProvider =
    FutureProvider.autoDispose<WaliStatus>((ref) async {
  final repo   = ref.watch(waliRepositoryProvider);
  final result = await repo.getStatus();
  return switch (result) {
    ApiSuccess(data: final s) => s,
    ApiError(error: final e)  => throw e.message,
  };
});

// ─────────────────────────────────────────────
// CONVERSATIONS  (wali reading ward messages)
// ─────────────────────────────────────────────

final waliConversationsProvider =
    FutureProvider.autoDispose<List<WaliConversation>>((ref) async {
  final repo   = ref.watch(waliRepositoryProvider);
  final result = await repo.getConversations();
  return switch (result) {
    ApiSuccess(data: final convs) => convs,
    ApiError()                    => <WaliConversation>[],
  };
});

// ─────────────────────────────────────────────
// PERMISSIONS UPDATE
// ─────────────────────────────────────────────

class PermissionsNotifier
    extends StateNotifier<AsyncValue<WaliPermissions>> {
  PermissionsNotifier(this._repo)
      : super(const AsyncValue.data(WaliPermissions()));

  final WaliRepository _repo;

  Future<bool> update(WaliPermissions perms) async {
    state = const AsyncValue.loading();
    final result = await _repo.updatePermissions(perms);
    return switch (result) {
      ApiSuccess(data: final p) => () {
          state = AsyncValue.data(p);
          return true;
        }(),
      ApiError(error: final e) => () {
          state = AsyncValue.error(e.message, StackTrace.current);
          return false;
        }(),
    };
  }
}

final permissionsProvider =
    StateNotifierProvider.autoDispose<PermissionsNotifier,
        AsyncValue<WaliPermissions>>((ref) {
  return PermissionsNotifier(ref.watch(waliRepositoryProvider));
});
