# MiskMatch Flutter App
## "Sealed with musk." — ختامه مسك — Quran 83:26

Islamic matrimony platform. Flutter + FastAPI.

---

## Sprint Status

| Sprint | Status | Description |
|--------|--------|-------------|
| **1 — Foundation** | ✅ **Done** | Scaffold, theme, API client, auth flow |
| 2 — Profile & Discovery | 🔜 Next | Profile wizard, swipe feed, compatibility |
| 3 — Active Match | 🔜 | Chat, WebSocket, voice messages |
| 4 — Games Hub | 🔜 | 17 games, async turns, Time Capsule |
| 5 — Wali Portal | 🔜 | Guardian dashboard, approve/decline |
| 6 — Polish & Release | 🔜 | Animations, TestFlight, Play Store |

---

## Project Structure

```
lib/
├── main.dart                        # App entry — ProviderScope, MaterialApp.router
├── core/
│   ├── api/
│   │   ├── api_client.dart          # Dio + interceptor chain
│   │   ├── api_endpoints.dart       # All endpoint path constants
│   │   └── interceptors/
│   │       ├── auth_interceptor.dart    # JWT Bearer injection
│   │       ├── refresh_interceptor.dart # Silent 401 → refresh → retry
│   │       └── logging_interceptor.dart # Dev pretty-printer
│   ├── config/
│   │   └── env.dart                 # Dev/staging/prod URLs, timeouts
│   ├── router/
│   │   └── app_router.dart          # GoRouter + auth guard redirect
│   ├── storage/
│   │   └── secure_storage.dart      # JWT persistence (Keychain / AES)
│   └── theme/
│       ├── app_colors.dart          # Rose Garden + Musk Night palette
│       ├── app_typography.dart      # Inter (Latin) + Scheherazade (Arabic)
│       └── app_theme.dart           # Full Material 3 theme, spacing, radius
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── auth_models.dart     # AuthTokens, AuthUser, request models
│   │   │   └── auth_repository.dart # API calls + token persistence
│   │   ├── providers/
│   │   │   └── auth_provider.dart   # AuthState sealed class + StateNotifier
│   │   └── screens/
│   │       ├── splash_screen.dart   # Bismillah + session restore
│   │       ├── phone_screen.dart    # Phone + gender + password
│   │       ├── otp_screen.dart      # 6-digit OTP + countdown resend
│   │       ├── niyyah_screen.dart   # Intention setting + hadith
│   │       └── wali_setup_screen.dart # Guardian registration
│   ├── discovery/   # Sprint 2
│   ├── match/       # Sprint 3
│   ├── games/       # Sprint 4
│   ├── wali/        # Sprint 5
│   └── profile/     # Sprint 3
└── shared/
    ├── models/
    │   └── api_response.dart    # ApiResult<T> sealed class, AppError
    └── widgets/
        ├── common_widgets.dart  # MiskButton, MiskTextField, MiskCard,
        │                        # TrustBadge, CompatibilityRing, ArabicText
        └── main_shell.dart      # Bottom nav shell (GoRouter ShellRoute)
```

---

## Getting Started

```bash
# Install dependencies
flutter pub get

# Run code generation (Freezed + Riverpod)
dart run build_runner build --delete-conflicting-outputs

# Run in development (connects to localhost:8000)
flutter run --dart-define=ENVIRONMENT=development

# Run against staging
flutter run --dart-define=ENVIRONMENT=staging

# Build for production
flutter build ios  --dart-define=ENVIRONMENT=production
flutter build apk  --dart-define=ENVIRONMENT=production
```

---

## Architecture

**State Management:** Riverpod 2.x with `StateNotifierProvider`
- Auth state: `authProvider` (sealed class: Initial/Loading/OtpSent/Authenticated/Error/Unauthenticated)
- All providers are typed — no dynamic casts

**Navigation:** GoRouter with auth guard
- Redirect logic in `routerProvider` watches `authProvider`
- All auth state changes automatically trigger navigation
- Deep links supported out of the box

**API Layer:** Dio + interceptor chain
- `AuthInterceptor` — injects Bearer token, skips for public routes
- `RefreshInterceptor` — catches 401, calls `/auth/refresh`, retries original request silently
- `LoggingInterceptor` — pretty-prints in dev only, stripped in prod

**Theme:** Material 3
- Rose Garden (light) + Musk Night (dark)
- System theme auto-switch
- Arabic: Scheherazade New font (bundled)
- Latin: Inter via Google Fonts

---

## Design Tokens

| Token | Value | Usage |
|-------|-------|-------|
| `roseDeep` | `#8B1A4A` | Primary buttons, headers |
| `roseBlush` | `#C4436A` | Interactive states |
| `goldPrimary` | `#C9973A` | Trust badges, premium |
| `midnightDeep` | `#1A0A2E` | Dark bg |
| `violetPrimary` | `#3D1A5E` | Dark theme primary |

---

## Backend Connection

The app talks to the MiskMatch FastAPI backend:
- Dev: `http://localhost:8000/api/v1`
- Prod: `https://api.miskmatch.app/api/v1`

Start the backend: `make setup` in the backend directory.
Test users: `yusuf@dev.miskmatch.app` / `Test1234!`
