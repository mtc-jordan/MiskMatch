import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/discovery_repository.dart';
import 'package:miskmatch/features/profile/data/profile_models.dart';
import 'package:miskmatch/shared/models/api_response.dart';

// Re-export so consumers can import from either location
export '../data/discovery_repository.dart' show DiscoveryFilters;

final discoveryFiltersProvider = StateProvider<DiscoveryFilters>(
  (_) => const DiscoveryFilters(),
);

// ─────────────────────────────────────────────
// FEED STATE
// ─────────────────────────────────────────────

class DiscoveryFeedState {
  const DiscoveryFeedState({
    this.candidates   = const [],
    this.isLoading    = false,
    this.isLoadingMore= false,
    this.hasMore      = true,
    this.page         = 1,
    this.error,
    this.expressedInterest = const {},
    this.dismissed         = const {},
  });

  final List<CandidateCard> candidates;
  final bool                isLoading;
  final bool                isLoadingMore;
  final bool                hasMore;
  final int                 page;
  final AppError?           error;
  final Set<String>         expressedInterest; // userId set
  final Set<String>         dismissed;         // userId set

  bool get isEmpty => !isLoading && candidates.isEmpty && error == null;

  /// Candidates not yet dismissed or interested in
  List<CandidateCard> get activeCandidates => candidates
      .where((c) =>
          !dismissed.contains(c.profile.userId) &&
          !expressedInterest.contains(c.profile.userId))
      .toList();

  DiscoveryFeedState copyWith({
    List<CandidateCard>? candidates,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
    AppError? error,
    Set<String>? expressedInterest,
    Set<String>? dismissed,
  }) =>
      DiscoveryFeedState(
        candidates:        candidates        ?? this.candidates,
        isLoading:         isLoading         ?? this.isLoading,
        isLoadingMore:     isLoadingMore     ?? this.isLoadingMore,
        hasMore:           hasMore           ?? this.hasMore,
        page:              page              ?? this.page,
        error:             error,
        expressedInterest: expressedInterest ?? this.expressedInterest,
        dismissed:         dismissed         ?? this.dismissed,
      );
}

// ─────────────────────────────────────────────
// FEED NOTIFIER
// ─────────────────────────────────────────────

class DiscoveryNotifier extends StateNotifier<DiscoveryFeedState> {
  DiscoveryNotifier(this._repo, this._filtersRef) : super(const DiscoveryFeedState());

  final DiscoveryRepository _repo;
  final Ref _filtersRef;

  DiscoveryFilters get _filters => _filtersRef.read(discoveryFiltersProvider);

  Future<void> loadFeed() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repo.getDiscovery(page: 1, filters: _filters);
    state = switch (result) {
      ApiSuccess(data: final cards) => state.copyWith(
          candidates:    cards,
          isLoading:     false,
          page:          1,
          hasMore:       cards.length >= 10,
          error:         null,
        ),
      ApiError(error: final e) => state.copyWith(
          isLoading: false,
          error:     e,
        ),
    };
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);
    final nextPage = state.page + 1;
    final result   = await _repo.getDiscovery(page: nextPage, filters: _filters);
    state = switch (result) {
      ApiSuccess(data: final cards) => state.copyWith(
          candidates:    [...state.candidates, ...cards],
          isLoadingMore: false,
          page:          nextPage,
          hasMore:       cards.length >= 10,
        ),
      ApiError() => state.copyWith(isLoadingMore: false),
    };
  }

  Future<bool> expressInterest({
    required String receiverId,
    required String message,
  }) async {
    final result = await _repo.expressInterest(
      receiverId: receiverId,
      message:    message,
    );
    if (result is ApiSuccess<String>) {
      state = state.copyWith(
        expressedInterest: {...state.expressedInterest, receiverId},
      );
      return true;
    }
    return false;
  }

  void dismiss(String userId) {
    state = state.copyWith(
      dismissed: {...state.dismissed, userId},
    );
  }

  void refresh() => loadFeed();
}

// ── Providers ─────────────────────────────────────────────────────────────────

final discoveryProvider =
    StateNotifierProvider<DiscoveryNotifier, DiscoveryFeedState>((ref) {
  return DiscoveryNotifier(ref.watch(discoveryRepositoryProvider), ref);
});

// ── Interest sending state ────────────────────────────────────────────────────

class InterestState {
  const InterestState({
    this.isSending = false,
    this.error,
    this.sentTo,
  });
  final bool    isSending;
  final String? error;
  final String? sentTo; // userId of last successful interest

  InterestState copyWith({bool? isSending, String? error, String? sentTo}) =>
      InterestState(
        isSending: isSending ?? this.isSending,
        error:     error,
        sentTo:    sentTo    ?? this.sentTo,
      );
}

class InterestNotifier extends StateNotifier<InterestState> {
  InterestNotifier(this._repo) : super(const InterestState());
  final DiscoveryRepository _repo;

  Future<bool> send({
    required String receiverId,
    required String message,
  }) async {
    state = state.copyWith(isSending: true, error: null);
    final result = await _repo.expressInterest(
        receiverId: receiverId, message: message);
    return switch (result) {
      ApiSuccess() => () {
          state = InterestState(sentTo: receiverId);
          return true;
        }(),
      ApiError(error: final e) => () {
          state = state.copyWith(isSending: false, error: e.message);
          return false;
        }(),
    };
  }
}

final interestProvider =
    StateNotifierProvider.autoDispose<InterestNotifier, InterestState>((ref) {
  return InterestNotifier(ref.watch(discoveryRepositoryProvider));
});
