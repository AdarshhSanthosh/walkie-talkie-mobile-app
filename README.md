# Walkie Talkie

Cross-platform push-to-talk voice app (Flutter/Dart). See the full product
spec discussed with the team for the end-to-end vision — this repo currently
implements **Phase 1** of that plan: a runnable UI scaffold with mock data,
no backend yet.

Visual design is matched to the reference at
[friend-chatterbox.lovable.app](https://friend-chatterbox.lovable.app) ("Holler"):
a warm cream background, a coral/orange accent for the TALK button and
highlights, and a mint-green online indicator. See [lib/app/theme.dart](lib/app/theme.dart)
for the palette and [lib/features/channels/channel_screen.dart](lib/features/channels/channel_screen.dart)
for the channel layout (friends list + recent transmissions + big TALK button)
it's modeled on.

## What's real vs. mocked right now

| Area | Status |
|---|---|
| Navigation (Splash → Login → Home → Channel → Create Channel) | ✅ Real (`go_router`) |
| Theme (Light/Dark/System), persisted | ✅ Real (`shared_preferences`) |
| TALK button (press-and-hold, haptics, local speaking state) | ✅ Real interaction, no real audio |
| Create Channel → invite code + QR code | ✅ Real (`qr_flutter`), channel is local-only |
| Auth (email/password, Google, Apple) | 🟡 Fake — any non-empty input logs in |
| Friends / presence | 🟡 Fake — static mock list |
| Channels | 🟡 Fake — static in-memory list |
| Voice (WebRTC), push notifications (FCM), Bluetooth routing | ⬜ Not implemented yet |

Every "fake" piece lives behind a service class in [lib/services/](lib/services/)
(`auth_service.dart`, `database_service.dart`, `presence_service.dart`,
`webrtc_service.dart`), each exposed as a Riverpod provider. Later phases
replace the implementation inside these files with real Supabase/Firebase/
WebRTC calls — the screens that consume them shouldn't need to change.

## Project structure

```
lib/
├── main.dart
├── app/            # MaterialApp.router, routes, theme
├── features/
│   ├── auth/       # splash + login
│   ├── home/       # bottom-nav shell + home tab
│   ├── friends/    # friends list (stub)
│   ├── channels/   # channel + create-channel screens
│   ├── voice/       # TALK button widget
│   └── settings/   # theme picker
├── services/       # fake service layer (see table above)
└── models/         # AppUser, VoiceChannel, enums
```

## Running it

Flutter 3.41.6, Android Studio, and the Android SDK are installed on this
machine, along with a **Pixel 8 / API 34 emulator** (`Pixel_8_API_34`,
hardware-accelerated via WHPX). Toolchain notes:

- Flutter's own JDK pick (Android Studio's bundled JBR, Java 25) is too new
  for the Gradle version the Flutter Android template pins — Android builds
  use **Eclipse Temurin JDK 21** instead, set via
  `flutter config --jdk-dir "C:/Program Files/Eclipse Adoptium/jdk-21.0.12.101-hotspot"`.
- `ANDROID_HOME`/`JAVA_HOME` are set at the Windows user-env level, so a
  fresh terminal picks them up automatically; `flutter doctor` should show
  every row green.

```bash
flutter pub get

# Start the emulator (if it isn't already running)
emulator -avd Pixel_8_API_34

# Run on it
flutter run -d emulator-5554
# or: flutter run -d chrome / flutter run -d windows
```

`flutter analyze` and `flutter test` are both clean, and the app has been
verified end-to-end on the emulator (login → home → channel → hold-to-talk
→ transmission logged).

## Next steps (later phases)

1. **Real auth** — wire `auth_service.dart` to Supabase Auth (email/password
   + Google/Apple OAuth). Requires a Supabase project (URL + anon key).
2. **Friends & blocking** — replace `presence_service.dart` with a Supabase
   Realtime-backed implementation; add request/accept/block flows.
3. **Real channels & permissions** — replace `database_service.dart` with
   Supabase tables (`channels`, `channel_members`) and role-based actions.
4. **Push-to-talk voice** — swap `webrtc_service.dart` for `flutter_webrtc` +
   a signaling channel (WebSocket or Supabase Realtime), plus a TURN server.
5. **Push notifications** — add Firebase Cloud Messaging (requires a
   Firebase project).
6. Reconnection handling, Bluetooth audio routing, accessibility polish,
   full Android/iOS device testing, and store release prep.
