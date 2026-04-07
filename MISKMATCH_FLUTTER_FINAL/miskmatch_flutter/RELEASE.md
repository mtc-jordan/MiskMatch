# MiskMatch — Release Runbook
## "ختامه مسك" — Sealed with musk. Quran 83:26

---

## Prerequisites

```
Flutter 3.16+     flutter --version
Xcode 15+         xcode-select --version        (macOS only, for iOS)
Android Studio    SDK 34, Build Tools 34.0.0
```

---

## 1. Environment Setup

### Clone and install
```bash
git clone https://github.com/noordigitallabs/miskmatch-flutter.git
cd miskmatch-flutter
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Fonts
Download **Scheherazade New** from Google Fonts and place in:
```
assets/fonts/ScheherazadeNew-Regular.ttf
assets/fonts/ScheherazadeNew-Bold.ttf
```

### Environment variables
Run with `--dart-define`:
```bash
# Development (connects to localhost:8000)
flutter run --dart-define=ENVIRONMENT=development

# Staging
flutter run --dart-define=ENVIRONMENT=staging

# Production
flutter run --dart-define=ENVIRONMENT=production
```

---

## 2. Backend Setup

```bash
cd miskmatch-backend
cp .env.example .env
# Fill in OPENAI_API_KEY, AWS_*, TWILIO_* in .env
make setup
# → Postgres + Redis start
# → Alembic migrations run (3 versions, 12 tables, 13 ENUMs)
# → Seed data loads (10 mosques, test users)
# → API at http://localhost:8000/docs
```

Test credentials: `yusuf@dev.miskmatch.app` / `Test1234!`

---

## 3. iOS — TestFlight

### One-time setup
1. Register App ID `app.miskmatch.ios` in Apple Developer portal
2. Create provisioning profiles (development + distribution)
3. In Xcode: open `ios/Runner.xcworkspace`
4. Set team and bundle ID in Signing & Capabilities

### Build and submit
```bash
# Clean build
flutter clean && flutter pub get

# Build release IPA
flutter build ios --release \
  --dart-define=ENVIRONMENT=production

# Open Xcode Organizer, archive, and upload to App Store Connect
open ios/Runner.xcworkspace
# Product → Archive → Distribute App → App Store Connect
```

### TestFlight checklist
- [ ] App icon 1024×1024 (no alpha) added in Assets.xcassets
- [ ] Launch screen configured
- [ ] Privacy manifest (PrivacyInfo.xcprivacy) added
- [ ] NSUserTrackingUsageDescription added if using analytics
- [ ] Export compliance: No encryption used beyond OS-level (HTTPS)
- [ ] Age rating: 17+ (matrimony app)

---

## 4. Android — Play Store

### Keystore (one-time)
```bash
keytool -genkey -v -keystore ~/miskmatch-release.jks \
  -alias miskmatch -keyalg RSA -keysize 2048 -validity 10000
```

### key.properties
Create `android/key.properties`:
```
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=miskmatch
storeFile=/Users/you/miskmatch-release.jks
```

### Build AAB (Play Store)
```bash
flutter build appbundle --release \
  --dart-define=ENVIRONMENT=production
# Output: build/app/outputs/bundle/release/app-release.aab
```

### Build APK (direct install / testing)
```bash
flutter build apk --release \
  --dart-define=ENVIRONMENT=production
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Play Store checklist
- [ ] App icon 512×512 PNG
- [ ] Feature graphic 1024×500 PNG
- [ ] 8+ screenshots (phone + tablet)
- [ ] Privacy policy URL
- [ ] Content rating: Completed (dating app → may require 17+)
- [ ] Data safety section completed
- [ ] Target API level 34+

---

## 5. Push Notifications — Firebase

### Setup
1. Create Firebase project at console.firebase.google.com
2. Add iOS app: `app.miskmatch.ios` → download `GoogleService-Info.plist`
3. Add Android app: `app.miskmatch` → download `google-services.json`
4. Place files:
   - `ios/Runner/GoogleService-Info.plist`
   - `android/app/google-services.json`

### Add to pubspec.yaml
```yaml
dependencies:
  firebase_core: ^3.x
  firebase_messaging: ^15.x
```

### Enable in notification_service.dart
Uncomment the `_setupFcm()` method and the manifest service entry.

### Backend FCM config
Set `FCM_SERVER_KEY` in backend `.env`.
The backend sends notifications via `app/services/notifications.py`.

---

## 6. App Icon Generation

### Tool: flutter_launcher_icons
```yaml
# Add to pubspec.yaml dev_dependencies:
flutter_launcher_icons: ^0.14.0

# Add to pubspec.yaml root:
flutter_icons:
  android: true
  ios: true
  image_path: "assets/icons/app_icon.png"  # 1024×1024 PNG, no alpha
  adaptive_icon_background: "#8B1A4A"       # roseDeep
  adaptive_icon_foreground: "assets/icons/app_icon_fg.png"
```

```bash
dart run flutter_launcher_icons
```

### Icon design brief
- Background: `#8B1A4A` (Rose Deep)
- Foreground: White Arabic ﻡ (meem) letterform, Scheherazade typeface
- Shape: Circle on iOS, adaptive on Android
- Dark mode: Same — the deep rose works on both

---

## 7. Splash Screen

### Tool: flutter_native_splash
```yaml
# Add to pubspec.yaml dev_dependencies:
flutter_native_splash: ^2.4.0

# Add to pubspec.yaml root:
flutter_native_splash:
  color: "#FBF0F3"          # roseWhite
  image: assets/images/splash_logo.png
  android_12:
    image: assets/images/splash_logo.png
    icon_background_color: "#FBF0F3"
  ios: true
  android: true
```

```bash
dart run flutter_native_splash:create
```

---

## 8. API Keys Reference

| Service       | Where Used                    | Key Name              |
|---------------|-------------------------------|-----------------------|
| OpenAI        | AI Deen Compatibility Engine  | `OPENAI_API_KEY`      |
| AWS S3        | Profile photos, voice intros  | `AWS_ACCESS_KEY_ID`   |
| Twilio        | Guardian OTP SMS              | `TWILIO_ACCOUNT_SID`  |
| Firebase FCM  | Push notifications            | `FCM_SERVER_KEY`      |
| Agora         | Chaperoned 3-way calls        | `AGORA_APP_ID`        |

All keys go in `miskmatch-backend/.env` (never committed to git).

---

## 9. App Store Description (English)

**Name:** MiskMatch  
**Subtitle:** Islamic Matrimony — "Sealed with musk"  
**Category:** Lifestyle / Social Networking

**Description:**
MiskMatch is the Islamic matrimony platform built on real values — not algorithms that reduce people to swipes. Every match includes your wali (guardian) from the beginning, meaningful questions through 17 curated games, and AI that matches on genuine Islamic character.

**Key features:**
• Wali Guardian Portal — your guardian is involved from day one
• 17 Match Games — get to know each other through values, not banter
• AI Deen Compatibility Engine — matches on Islamic practice, life goals, and personality
• Two-layer Islamic chat moderation — content guidelines, automatically enforced
• Voice introductions — hear someone before you see them
• Time Capsule — write letters to your future selves, opened on Day 21
• Chaperoned 3-way video calls — family-inclusive communication

**Keywords:** Islamic marriage, Muslim matrimony, halal dating, wali, nikah, marriage apps

---

## 10. Pre-Launch Checklist

### Backend
- [ ] All 174 tests passing
- [ ] Migrations applied on prod database
- [ ] Redis and Celery workers running
- [ ] OpenAI key set and embeddings working
- [ ] AWS S3 bucket created and CORS configured
- [ ] Twilio number active for OTP SMS
- [ ] SSL certificate on API domain

### Flutter
- [ ] `ENVIRONMENT=production` build tested on physical device
- [ ] Offline error states tested (no network)
- [ ] Deep links tested (miskmatch://match/xxx)
- [ ] Arabic content rendering checked (RTL, Scheherazade font)
- [ ] Dark mode tested end-to-end
- [ ] Voice recording and playback tested on device
- [ ] OTP flow tested with real phone number
- [ ] Wali flow tested (invite → accept → approve match)
- [ ] All 17 games tested (at least one turn each)

### Legal
- [ ] Privacy policy live at miskmatch.app/privacy
- [ ] Terms of service live at miskmatch.app/terms
- [ ] GDPR/data deletion endpoint available
- [ ] Cookie policy (if web version)

---

*Noor Digital Labs — Amman, Jordan*  
*info@miskmatch.app*
