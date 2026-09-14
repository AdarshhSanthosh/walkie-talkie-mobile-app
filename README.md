# Walkie Talkie

Cross-platform push-to-talk voice app (Flutter/Dart). See the full product
spec discussed with the team for the end-to-end vision. This repo has:

- **Phase 1** done: a runnable UI scaffold with mock data.
- **Phase 2** done: real Supabase authentication + profiles (verified live).
- **Phase 3** done: real friends, requests, and blocking (verified live).
- **Phase 4** done: real channels, membership, and basic permissions.

Visual design is matched to the reference at
[friend-chatterbox.lovable.app](https://friend-chatterbox.lovable.app) ("Holler"):
a warm cream background, a coral/orange accent for the TALK button and
highlights, and a mint-green online indicator. See [lib/app/theme.dart](lib/app/theme.dart)
for the palette and [lib/features/channels/channel_screen.dart](lib/features/channels/channel_screen.dart)
for the channel layout (member list + recent transmissions + big TALK button)
it's modeled on.

## What's real vs. mocked right now

| Area | Status |
|---|---|
| Navigation (Splash → Login → Sign Up → Home → Channel → Create/Join Channel) | ✅ Real (`go_router`) |
| Auth (email/password) | ✅ Real (Supabase Auth) — verified live |
| Profiles (`profiles` table, display name shown on Home) | ✅ Real (Supabase Postgres) — verified live |
| Friends: search, requests, accept/reject, remove, block/unblock | ✅ Real (Supabase Postgres + RPCs) — verified live |
| Channels: create, join by code, leave, delete, remove member | ✅ Real (Supabase Postgres + RPCs) |
| Theme (Light/Dark/System), persisted | ✅ Real (`shared_preferences`) |
| TALK button (press-and-hold, haptics, local speaking state) | ✅ Real interaction, no real audio |
| Create Channel → invite code + QR code | ✅ Real, backed by a real channel row now |
| Auth (Google, Apple) | 🟡 Wired, but needs providers enabled in the Supabase dashboard first |
| Channel moderation (mute/ban/role changes) | 🟡 Schema ready (`muted`/`banned`/`role` columns), no RPCs/UI wired yet |
| Voice (WebRTC), push notifications (FCM), Bluetooth routing | ⬜ Not implemented yet |

Every "fake" piece lives behind a service class in [lib/services/](lib/services/),
each exposed as a Riverpod provider — `auth_service.dart`, `profile_service.dart`,
`friends_service.dart`, and `channels_service.dart` are all real Supabase calls now;
only `webrtc_service.dart` is still a fake, ready to be swapped in Phase 5.

## Project structure

```
lib/
├── main.dart
├── app/            # MaterialApp.router, routes, theme
├── core/config/     # Supabase env config + "not configured" fallback screen
├── features/
│   ├── auth/       # splash + login + sign up
│   ├── home/       # bottom-nav shell + home tab
│   ├── friends/    # search, requests, friends list (real)
│   ├── channels/   # channel, create-channel, join-channel screens (real)
│   ├── voice/       # TALK button widget
│   └── settings/   # theme picker + blocked users
├── services/       # auth/profile/friends/channels are real Supabase; webrtc is still fake
└── models/         # AppUser, VoiceChannel, ChannelMember, FriendRequest, enums
supabase/
├── schema.sql           # profiles table + RLS + auto-create-on-signup trigger
├── friends_schema.sql   # friend_requests/friendships/blocked_users + RPCs
└── channels_schema.sql  # channels/channel_members + RPCs
```

## One-time setup: Supabase project

1. Create a project at [supabase.com](https://supabase.com/dashboard) (free tier is fine).
2. Open the SQL Editor and run, **in order**: [supabase/schema.sql](supabase/schema.sql),
   then [supabase/friends_schema.sql](supabase/friends_schema.sql), then
   [supabase/channels_schema.sql](supabase/channels_schema.sql) — each later
   one depends on tables the earlier ones create.
   - `schema.sql` creates `profiles` + a trigger that auto-creates a profile
     row whenever someone signs up.
   - `friends_schema.sql` creates `friend_requests`/`friendships`/
     `blocked_users` plus RPC functions.
   - `channels_schema.sql` creates `channels`/`channel_members` plus RPC
     functions (`create_channel`, `join_channel_by_code`, `leave_channel`,
     `remove_channel_member`, `delete_channel`).
   - All of the above: state changes go through RPCs rather than raw table
     writes, so the server (not the client) enforces who's allowed to do
     what.
3. In Project Settings → API, copy the **Project URL** and the **anon
   public** (or new-style **publishable**) key.
4. Copy `env.example.json` to `env.json` (gitignored — never commit real
   keys) and fill in those two values.
5. Under Authentication → Sign In / Providers → **Email**, make sure both
   "Allow new users to sign up" (User Signups section) and the Email
   provider itself are enabled — these are separate toggles from "Confirm
   email" and easy to miss.

Google/Apple sign-in additionally need their providers enabled under
Authentication → Providers, plus your own Google Cloud / Apple Developer
OAuth credentials — not set up yet. The buttons are wired and will show a
clear "provider not enabled" error until that's done; email/password is
fully functional without it.

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

# Run on it, passing your Supabase credentials (see setup above)
flutter run -d emulator-5554 --dart-define-from-file=env.json
# or: flutter run -d chrome --dart-define-from-file=env.json
```

Without `env.json` configured, the app shows a "Supabase isn't configured"
screen instead of crashing, with the same setup steps as above.

**Important**: after any code change, redeploy with `flutter run` again —
the emulator only ever runs whatever was last installed on it, hot reload
aside. It's easy to test against a stale build otherwise.

`flutter analyze` and `flutter test` are both clean. Phases 1–3 have been
verified live end-to-end on the emulator (sign up → confirm → log in → real
name shown → friend request → accept → block/unblock, across two real test
accounts). Phase 4 (channels) is written and analyzed against the same live
project, pending a live run-through — see "Next steps".

## Next steps (later phases)

1. **Finish verifying Phase 4 live** — run `channels_schema.sql`, then
   create a channel, join it from a second account via its invite code,
   remove a member, and leave/delete on the emulator.
2. **Push-to-talk voice** — swap `webrtc_service.dart` for `flutter_webrtc` +
   a signaling channel (WebSocket or Supabase Realtime), plus a TURN server.
3. **Push notifications** — add Firebase Cloud Messaging (requires a
   Firebase project).
4. Reconnection handling, Bluetooth audio routing, accessibility polish,
   full Android/iOS device testing, and store release prep.
