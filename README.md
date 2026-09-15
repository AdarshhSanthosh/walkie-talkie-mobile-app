# Walkie Talkie

Cross-platform push-to-talk voice app (Flutter/Dart). See the full product
spec discussed with the team for the end-to-end vision. This repo has:

- **Phase 1** done: a runnable UI scaffold with mock data.
- **Phase 2** done: real Supabase authentication + profiles (verified live).
- **Phase 3** done: real friends, requests, and blocking (verified live).
- **Phase 4** done: real channels, membership, and basic permissions (verified live).
- **Phase 5** done: real WebRTC push-to-talk voice + signaling (verified live for signaling; see caveat below).
- **Phase 6** done: real in-app notifications + preferences (verified live; device push delivery pending a Firebase project — see below).

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
| Channels: create, join by code, leave, delete, remove member | ✅ Real (Supabase Postgres + RPCs) — verified live |
| Push-to-talk voice: mic permission, WebRTC mesh, live signaling/presence | ✅ Real (`flutter_webrtc` + Supabase Realtime) — signaling verified live across two real peers |
| Theme (Light/Dark/System), persisted | ✅ Real (`shared_preferences`) |
| Create Channel → invite code + QR code | ✅ Real, backed by a real channel row |
| Auth (Google, Apple) | 🟡 Wired, but needs providers enabled in the Supabase dashboard first |
| Channel moderation (mute/ban/role changes) | 🟡 Schema ready (`muted`/`banned`/`role` columns), no RPCs/UI wired yet |
| Actual audio connectivity between peers | 🟡 Signaling confirmed working; media (ICE/RTP) not yet confirmed — see caveat |
| Notifications: friend request/accept, channel-join alerts, read/unread inbox | ✅ Real (Supabase Postgres + RPCs) — verified live |
| Notification preferences: 6 global toggles + per-channel All/Important/Muted | ✅ Real, persisted (Settings → Notifications; channel header menu) |
| Actual push delivery to a device (FCM) | ⬜ Not wired — needs a Firebase project; `device_tokens` table is ready to receive tokens |
| Bluetooth routing | ⬜ Not implemented yet |

Every piece now lives behind a service class in [lib/services/](lib/services/),
each exposed as a Riverpod provider — `auth_service.dart`, `profile_service.dart`,
`friends_service.dart`, `channels_service.dart`, `webrtc_service.dart`, and
`notifications_service.dart` are all real now. Nothing is left mocked except
actual FCM push delivery (see Phase 6 section below).

### Notifications (Phase 6)

Real rows in a `notifications` table, generated server-side (inside the same
RPCs from Phases 3/4) whenever: someone sends you a friend request, someone
accepts yours, or someone joins a channel you own — each respecting the
recipient's global preference toggle and, for channel joins, their
per-channel mute level. The Home screen's bell icon shows a live unread
count; tapping a notification marks it read. None of this reaches a device
as an actual push notification yet — that needs a Firebase project
(`firebase_core`/`firebase_messaging` in the app, plus a Supabase Edge
Function to call the FCM API when a notification row is inserted, since
Postgres can't call FCM directly). `register_device_token`/`device_tokens`
are ready for that; nothing calls them yet.

### Voice architecture (Phase 5)

`webrtc_service.dart` implements a **mesh** of direct WebRTC connections — one
per other peer in the channel — signaled over a Supabase Realtime channel
(`voice:{channelId}`). Realtime **presence** on that channel doubles as "who's
listening right now" (replacing the old static `profiles.status`), carries
each peer's live `speaking` flag (drives the "🎙 X is transmitting" text for
everyone, not just the local user), and **broadcast** messages carry the
SDP offer/answer/ICE-candidate exchange. This is a small-group design (spec
§7 calls mesh fine for dev/testing); a production build with larger channels
would swap this for an SFU without changing the public API
(`startTalking`/`stopTalking`).

**Caveat — verified so far**: on two real, separate peers (an Android
emulator and an isolated headless Chrome instance, each running its own
account), the full flow up through **signaling** was confirmed live: mic
permission granted, Realtime presence showed both peers ("2 online"), and a
real SDP offer/answer exchange happened between them. The ICE connection
itself didn't complete in that test — STUN requests timed out on every
network interface on the emulator side, consistent with this specific sandboxed
dev environment restricting outbound UDP (needed for STUN/ICE) rather than
an app bug; TCP-based signaling worked throughout. **This should be
re-verified on two real devices on a normal network** (e.g. two phones on
the same WiFi) before relying on it — that's a materially different network
path than an emulator's virtualized NAT. If it turns out real networks also
need help, the architecture already anticipates a TURN server (spec §7) —
none is configured yet; only public STUN (`stun.l.google.com`).

## Project structure

```
lib/
├── main.dart
├── app/            # MaterialApp.router, routes, theme
├── core/config/     # Supabase env config + "not configured" fallback screen
├── features/
│   ├── auth/           # splash + login + sign up
│   ├── home/           # bottom-nav shell + home tab
│   ├── friends/        # search, requests, friends list (real)
│   ├── channels/       # channel, create-channel, join-channel screens (real)
│   ├── voice/          # TALK button widget
│   ├── notifications/  # notifications inbox screen
│   └── settings/       # theme picker, blocked users, notification prefs
├── services/       # all real Supabase/WebRTC now — no fakes left
└── models/         # AppUser, VoiceChannel, ChannelMember, FriendRequest,
                     # NotificationItem, NotificationPreferences, enums
supabase/
├── schema.sql                # profiles table + RLS + auto-create-on-signup trigger
├── friends_schema.sql        # friend_requests/friendships/blocked_users + RPCs
├── channels_schema.sql       # channels/channel_members + RPCs
└── notifications_schema.sql  # notifications/preferences/device_tokens + RPCs
```

## One-time setup: Supabase project

1. Create a project at [supabase.com](https://supabase.com/dashboard) (free tier is fine).
2. Open the SQL Editor and run, **in order**: [supabase/schema.sql](supabase/schema.sql),
   then [supabase/friends_schema.sql](supabase/friends_schema.sql), then
   [supabase/channels_schema.sql](supabase/channels_schema.sql), then
   [supabase/notifications_schema.sql](supabase/notifications_schema.sql) —
   each later one depends on tables the earlier ones create.
   - `schema.sql` creates `profiles` + a trigger that auto-creates a profile
     row whenever someone signs up.
   - `friends_schema.sql` creates `friend_requests`/`friendships`/
     `blocked_users` plus RPC functions.
   - `channels_schema.sql` creates `channels`/`channel_members` plus RPC
     functions (`create_channel`, `join_channel_by_code`, `leave_channel`,
     `remove_channel_member`, `delete_channel`).
   - `notifications_schema.sql` creates `notifications`/
     `notification_preferences`/`device_tokens`, extends the signup trigger
     to seed default preferences, and redefines the friend/channel RPCs
     above to also raise a real notification (respecting the recipient's
     preferences).
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
6. Realtime is on by default for new Supabase projects (needed for Phase 5
   voice signaling/presence) — no extra setup unless you've changed it.

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
- `permission_handler` is pinned to `11.3.1` (not the latest `13.x`) —
  `permission_handler_android 14.1.0`'s Gradle script fails to compile
  against this project's AGP/Kotlin combo (`Unresolved reference:
  compilerOptions`). Revisit the pin next time dependencies are bumped.

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

`flutter analyze` and `flutter test` are both clean. Phases 1–4 have been
verified live end-to-end (sign up → confirm → log in → real name shown →
friend request → accept → block/unblock → create channel → join by code →
remove/leave/delete, across two real test accounts). Phase 5's signaling
layer is verified live the same way; full audio connectivity needs
re-confirming on real devices — see the voice architecture caveat above.
Phase 6 has also been verified live: sending a friend request raised a real
notification with a live unread badge on the recipient's Home screen,
tapping it marked it read (persisted), and turning off "Friend Requests" in
Settings → Notifications correctly suppressed a repeat notification for the
same action — confirmed by checking the `notifications` table directly.

## Next steps (later phases)

1. **Confirm Phase 5 audio on real devices** — two phones on the same WiFi,
   hold TALK on one, confirm the other hears it and the speaking indicator
   updates. Set up a TURN server (e.g. `coturn` or a managed provider) if
   direct connections turn out to need help even off the emulator.
2. **Wire actual push delivery (Phase 6)** — create a Firebase project, add
   `firebase_core`/`firebase_messaging` to the app, call
   `register_device_token` with the resulting FCM token, and add a Supabase
   Edge Function (triggered by a Database Webhook on `notifications`
   inserts) that calls the FCM HTTP v1 API to actually push to the stored
   tokens.
3. Reconnection handling (spec §19), Bluetooth audio routing, accessibility
   polish, full Android/iOS device testing, and store release prep.
