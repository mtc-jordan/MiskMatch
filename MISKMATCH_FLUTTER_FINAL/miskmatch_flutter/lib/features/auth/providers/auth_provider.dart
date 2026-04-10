import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';
import 'package:miskmatch/shared/models/api_response.dart';

// ─────────────────────────────────────────────
// AUTH STATE
// ─────────────────────────────────────────────

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthOtpSent extends AuthState {
  const AuthOtpSent({required this.phone, required this.isNewUser});
  final String phone;
  final bool   isNewUser;
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({required this.userId, required this.needsOnboarding, this.gender});
  final String  userId;
  final bool    needsOnboarding;
  final String? gender;
}

class AuthError extends AuthState {
  const AuthError({required this.error});
  final AppError error;
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

// ─────────────────────────────────────────────
// AUTH NOTIFIER
// ─────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo) : super(const AuthInitial());

  final AuthRepository _repo;

  // ── Phone registration (new user) ─────────────────────────────────────────
  Future<void> register({
    required String phone,
    required String password,
    required String gender,
    String? niyyah,
  }) async {
    state = const AuthLoading();

    final result = await _repo.register(
      RegisterRequest(
        phone:    phone,
        password: password,
        gender:   gender,
        niyyah:   niyyah,
      ),
    );

    state = switch (result) {
      ApiSuccess() => AuthOtpSent(phone: phone, isNewUser: true),
      ApiError(error: final e) => AuthError(error: e),
    };
  }

  // ── Login (existing user) ─────────────────────────────────────────────────
  Future<void> login({
    required String phone,
    required String password,
  }) async {
    state = const AuthLoading();

    final result = await _repo.login(
      LoginRequest(phone: phone, password: password),
    );

    state = switch (result) {
      ApiSuccess(data: final tokens) => AuthAuthenticated(
          userId:          tokens.userId,
          needsOnboarding: !tokens.onboardingCompleted,
          gender:          tokens.gender,
        ),
      ApiError(error: final e) => AuthError(error: e),
    };
  }

  // ── Verify OTP ────────────────────────────────────────────────────────────
  Future<void> verifyOtp({
    required String phone,
    required String otp,
    required bool   isNewUser,
  }) async {
    state = const AuthLoading();

    final result = await _repo.verifyOtp(
      OtpVerifyRequest(phone: phone, otp: otp),
    );

    state = switch (result) {
      ApiSuccess(data: final tokens) => AuthAuthenticated(
          userId:          tokens.userId,
          needsOnboarding: isNewUser,
          gender:          tokens.gender,
        ),
      ApiError(error: final e) => AuthError(error: e),
    };
  }

  // ── Resend OTP ────────────────────────────────────────────────────────────
  Future<ApiResult<String>> resendOtp(String phone) =>
      _repo.resendOtp(phone);

  // ── Restore session ───────────────────────────────────────────────────────
  Future<void> checkSession() async {
    final hasSession = await _repo.hasActiveSession();
    if (hasSession) {
      final userId = await _repo.storage.getUserId();
      final gender = await _repo.storage.getGender();
      state = AuthAuthenticated(
        userId:          userId ?? '',
        needsOnboarding: false,
        gender:          gender,
      );
    } else {
      state = const AuthUnauthenticated();
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    state = const AuthLoading();
    await _repo.logout();
    state = const AuthUnauthenticated();
  }

  // ── Complete onboarding ────────────────────────────────────────────────────
  void completeOnboarding() {
    final current = state;
    if (current is AuthAuthenticated) {
      state = AuthAuthenticated(
        userId: current.userId,
        needsOnboarding: false,
        gender: current.gender,
      );
    }
  }

  // ── Clear error ───────────────────────────────────────────────────────────
  void clearError() {
    if (state is AuthError) {
      state = const AuthUnauthenticated();
    }
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

/// Convenience: currently authenticated user ID
final currentUserIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(authProvider);
  if (auth is AuthAuthenticated) return auth.userId;
  return null;
});

/// Currently authenticated user's gender
final currentUserGenderProvider = Provider<String?>((ref) {
  final auth = ref.watch(authProvider);
  if (auth is AuthAuthenticated) return auth.gender;
  return null;
});

/// Whether any auth action is in progress
final authLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authProvider) is AuthLoading;
});
