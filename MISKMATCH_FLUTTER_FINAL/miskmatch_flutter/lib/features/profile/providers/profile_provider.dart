import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/profile_models.dart';
import '../data/profile_repository.dart';
import 'package:miskmatch/shared/models/api_response.dart';

// ─────────────────────────────────────────────
// MY PROFILE STATE
// ─────────────────────────────────────────────

sealed class ProfileState {
  const ProfileState();
}
class ProfileInitial    extends ProfileState { const ProfileInitial(); }
class ProfileLoading    extends ProfileState { const ProfileLoading(); }
class ProfileLoaded     extends ProfileState {
  const ProfileLoaded(this.profile);
  final UserProfile profile;
}
class ProfileSaving     extends ProfileState {
  const ProfileSaving(this.profile);
  final UserProfile profile;
}
class ProfileError      extends ProfileState {
  const ProfileError(this.error);
  final AppError error;
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  ProfileNotifier(this._repo) : super(const ProfileInitial());

  final ProfileRepository _repo;

  Future<void> load() async {
    state = const ProfileLoading();
    final result = await _repo.getMyProfile();
    state = switch (result) {
      ApiSuccess(data: final p) => ProfileLoaded(p),
      ApiError(error: final e)  => ProfileError(e),
    };
  }

  Future<bool> createProfile(UserProfile profile) async {
    final current = state is ProfileLoaded
        ? (state as ProfileLoaded).profile
        : null;
    state = ProfileSaving(current ?? profile);

    final result = await _repo.createProfile(profile);
    return switch (result) {
      ApiSuccess(data: final p) => () {
          state = ProfileLoaded(p);
          _repo.triggerReembed();
          return true;
        }(),
      ApiError(error: final e) => () {
          state = ProfileError(e);
          return false;
        }(),
    };
  }

  Future<bool> updateProfile(UserProfile profile) async {
    state = ProfileSaving(profile);
    final result = await _repo.updateProfile(profile);
    return switch (result) {
      ApiSuccess(data: final p) => () {
          state = ProfileLoaded(p);
          _repo.triggerReembed();
          return true;
        }(),
      ApiError(error: final e) => () {
          state = ProfileError(e);
          return false;
        }(),
    };
  }

  Future<bool> uploadPhoto(File photo) async {
    final result = await _repo.uploadPhoto(photo);
    if (result is ApiSuccess<String> && state is ProfileLoaded) {
      final current = (state as ProfileLoaded).profile;
      state = ProfileLoaded(current.copyWith(photoUrl: result.data));
      return true;
    }
    return false;
  }

  Future<bool> uploadVoiceIntro(File audio) async {
    final result = await _repo.uploadVoiceIntro(audio);
    if (result is ApiSuccess<String> && state is ProfileLoaded) {
      final current = (state as ProfileLoaded).profile;
      state = ProfileLoaded(current.copyWith(voiceIntroUrl: result.data));
      return true;
    }
    return false;
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier(ref.watch(profileRepositoryProvider));
});

/// Quick access to the loaded profile (null if not yet loaded)
final myProfileProvider = Provider<UserProfile?>((ref) {
  final state = ref.watch(profileProvider);
  return state is ProfileLoaded ? state.profile : null;
});

/// Profile completion percentage (async)
final profileCompletionProvider =
    FutureProvider.autoDispose<ProfileCompletion>((ref) async {
  final repo   = ref.watch(profileRepositoryProvider);
  final result = await repo.getCompletion();
  return switch (result) {
    ApiSuccess(data: final c) => c,
    ApiError()                => const ProfileCompletion(
        percentage: 0, missingFields: [], nextStep: null),
  };
});
