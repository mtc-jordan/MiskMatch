# MiskMatch Flutter App
## Islamic Matrimony Platform
### *"Sealed with musk."* — Quran 83:26

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter 3.x + Dart |
| **State** | Riverpod 2.x (StateNotifier) |
| **Navigation** | GoRouter with auth guard |
| **API** | Dio + interceptor chain |
| **Storage** | flutter_secure_storage (Keychain / AES) |
| **WebSocket** | web_socket_channel (chat + games) |
| **Notifications** | Firebase Cloud Messaging |
| **Video** | Agora RTC Engine |
| **Audio** | record package (voice messages) |
| **Theme** | Material 3 (Rose Garden / Musk Night) |

---

## Features

All features are implemented (74 Dart files across 9 feature modules):

| Feature | Status | Description |
|---------|--------|-------------|
| **Auth** | Done | Phone + OTP login, niyyah (intention), session restore |
| **Profile** | Done | Multi-step wizard, photo/voice/Quran upload, Sifr personality |
| **Discovery** | Done | AI-ranked swipe feed, compatibility preview |
| **Match** | Done | Interest, accept/decline, match detail, close/nikah |
| **Chat** | Done | Real-time WebSocket, voice messages, AI moderation alerts |
| **Games** | Done | 17 Islamic compatibility games, real-time + async turns |
| **Calls** | Done | Agora chaperoned video calls, wali approval |
| **Wali** | Done | Guardian portal, dashboard, match oversight |
| **Settings** | Done | Account settings, preferences |

---

## Project Structure

```
lib/
├── main.dart                         # ProviderScope + MaterialApp.router
├── core/
│   ├── api/
│   │   ├── api_client.dart           # Dio setup, cert pinning placeholder
│   │   ├── api_endpoints.dart        # All endpoint path constants
│   │   └── interceptors/
│   │       ├── auth_interceptor.dart     # JWT Bearer injection
│   │       ├── refresh_interceptor.dart  # Silent 401 → refresh → retry
│   │       └── logging_interceptor.dart  # Dev-only pretty-printer
│   ├── config/
│   │   └── env.dart                  # Dev/staging/prod URLs + timeouts
│   ├── notifications/
│   │   └── notification_service.dart # FCM setup + handling
│   ├── router/
│   │   └── app_router.dart           # GoRouter + auth redirect guard
│   ├── storage/
│   │   └── secure_storage.dart       # JWT + userId persistence
│   ├── theme/
│   │   ├── app_colors.dart           # Rose Garden + Musk Night palette
│   │   ├── app_typography.dart       # Inter (Latin) + Scheherazade (Arabic)
│   │   └── app_theme.dart            # Full Material 3 theme
│   └── websocket/
│       └── websocket_service.dart    # WS connection, reconnect, ping
├── features/
│   ├── auth/
│   │   ├── data/                     # AuthTokens, AuthUser models, repository
│   │   ├── providers/                # AuthState sealed class + notifier
│   │   └── screens/                  # Splash, Phone, OTP, Niyyah, WaliSetup
│   ├── profile/
│   │   ├── data/                     # Profile models, repository
│   │   ├── providers/                # Profile state, completion tracking
│   │   ├── screens/                  # Edit, wizard steps, media upload
│   │   └── widgets/                  # Profile card, stats, trust badge
│   ├── discovery/
│   │   ├── data/                     # Discovery models, repository
│   │   ├── providers/                # Discovery feed, filters
│   │   ├── screens/                  # Swipe feed, compatibility preview
│   │   └── widgets/                  # Profile cards, compatibility ring
│   ├── match/
│   │   ├── data/                     # Match models, repository
│   │   ├── providers/                # Match list, detail providers
│   │   ├── screens/                  # Match list, detail, respond
│   │   └── widgets/                  # Match card, status badges
│   ├── chat/
│   │   ├── data/                     # Message models, chat repository
│   │   ├── providers/                # Chat state, WebSocket integration
│   │   ├── screens/                  # Chat screen, conversation list
│   │   └── widgets/                  # Message bubbles, input bar, voice recorder
│   ├── games/
│   │   ├── data/                     # Game models, repository
│   │   ├── providers/                # Game state, real-time sync
│   │   ├── screens/                  # Game hub, individual game screens
│   │   └── widgets/                  # Game cards, turn indicators
│   ├── calls/
│   │   ├── data/                     # Call models, repository
│   │   ├── providers/                # Call state, Agora integration
│   │   ├── screens/                  # Call screen, history
│   │   └── widgets/                  # Call controls, timer
│   ├── wali/
│   │   ├── data/                     # Wali models, repository
│   │   ├── providers/                # Wali dashboard state
│   │   ├── screens/                  # Dashboard, ward list, match review
│   │   └── widgets/                  # Ward card, approval buttons
│   └── settings/
│       ├── providers/                # Settings state
│       └── screens/                  # Settings, account deletion
└── shared/
    ├── models/
    │   └── api_response.dart         # ApiResult<T> sealed class, AppError
    └── widgets/
        ├── common_widgets.dart       # MiskButton, MiskTextField, MiskCard,
        │                             # TrustBadge, CompatibilityRing, ArabicText
        └── main_shell.dart           # Bottom nav shell (GoRouter ShellRoute)
```

---

## Getting Started

### Prerequisites

- Flutter SDK 3.x
- Android Studio / Xcode
- Running MiskMatch backend (see backend README)

### Setup

```bash
cd miskmatch_flutter

# Install dependencies
flutter pub get

# Run code generation (if using Freezed / build_runner)
dart run build_runner build --delete-conflicting-outputs

# Run in development (connects to localhost:8000)
flutter run --dart-define=ENVIRONMENT=development

# Run against staging
flutter run --dart-define=ENVIRONMENT=staging

# Build release
flutter build apk --dart-define=ENVIRONMENT=production
flutter build ios --dart-define=ENVIRONMENT=production
```

### Backend Connection

| Environment | API Base URL |
|---|---|
| Development | `http://10.0.2.2:8000/api/v1` (Android emulator) |
| Development | `http://localhost:8000/api/v1` (iOS simulator) |
| Staging | `https://staging-api.miskmatch.app/api/v1` |
| Production | `https://api.miskmatch.app/api/v1` |

Configure in `lib/core/config/env.dart`.

---

## Architecture

### State Management — Riverpod 2.x

- `StateNotifierProvider` for complex state (auth, chat, games)
- `FutureProvider` for async data fetching (profiles, matches)
- Sealed classes for exhaustive state handling
- All providers are typed — no dynamic casts

### Navigation — GoRouter

- Auth guard watches `authProvider` state
- Automatic redirect: unauthenticated → phone screen
- Deep link support built-in
- `ShellRoute` for bottom navigation shell

### API Layer — Dio

Three interceptors in chain:
1. **AuthInterceptor** — injects `Authorization: Bearer <token>`, skips for public routes
2. **RefreshInterceptor** — catches 401, calls `/auth/refresh`, retries original request
3. **LoggingInterceptor** — pretty-prints request/response in dev mode only

### WebSocket

- Per-match WebSocket connection for real-time chat and games
- Auto-reconnect with exponential backoff
- Ping/pong keepalive
- Pending message queue (messages queued during disconnection)

### Theme — Material 3

| Mode | Name | Primary |
|---|---|---|
| Light | Rose Garden | `#8B1A4A` (roseDeep) |
| Dark | Musk Night | `#3D1A5E` (violetPrimary) |

- System theme auto-switch
- Arabic typography: Scheherazade New (bundled)
- Latin typography: Inter (Google Fonts)

---

## Design Tokens

| Token | Hex | Usage |
|-------|-----|-------|
| `roseDeep` | `#8B1A4A` | Primary buttons, headers |
| `roseBlush` | `#C4436A` | Interactive states |
| `goldPrimary` | `#C9973A` | Trust badges, premium features |
| `midnightDeep` | `#1A0A2E` | Dark mode background |
| `violetPrimary` | `#3D1A5E` | Dark theme primary |

---

*MiskMatch Flutter — Built with barakah*
*"Sealed with musk." — Quran 83:26*
