# Chick Talk

Cross-platform push-to-talk voice app (Flutter/Dart), branded **Chick Talk**
(app icon + display name — see the branding section below). See the full
product spec discussed with the team for the end-to-end vision. This repo
has:

- **Phase 1** done: a runnable UI scaffold with mock data.
- **Phase 2** done: real Supabase authentication + profiles (verified live).
- **Phase 3** done: real friends, requests, and blocking (verified live).
- **Phase 4** done: real channels, membership, and basic permissions (verified live).
- **Phase 5** done: real WebRTC push-to-talk voice + signaling (verified live for signaling; see caveat below).
- **Phase 6** done: real in-app notifications + preferences (verified live; device push delivery pending a Firebase project — see below).
- **Phase 7** done: reconnection handling, background behavior, and error surfacing (spec §19) (verified live).
- **Phase 8** done: Bluetooth-aware audio routing (spec §8) (verified live on the emulator; real Bluetooth-device routing needs a physical device — see below).
- **Phase 9** partially done: a full regression pass across every screen on the Android emulator (verified live); real-device and iOS testing are blocked by this environment — see below.

Visual design is matched to the reference at
[friend-chatterbox.lovable.app](https://friend-chatterbox.lovable.app) ("Holler"):
a warm cream background, a coral/orange accent for the TALK button and
highlights, and a mint-green online indicator. See [lib/app/theme.dart](lib/app/theme.dart)
for the palette and [lib/features/channels/channel_screen.dart](lib/features/channels/channel_screen.dart)
for the channel layout (member list + recent transmissions + big TALK button)
it's modeled on.

## Branding

App icon and display name ("Chick Talk") are real, generated via
`flutter_launcher_icons` from [assets/icon/app_icon_source.png](assets/icon/app_icon_source.png)
(a full-bleed square — the provided artwork's black corners were flood-filled
with its yellow background so each platform's own mask shape, e.g. iOS's
squircle or Android's adaptive-icon shape, applies cleanly instead of
clipping a pre-rounded image). Covers Android (including the adaptive icon,
background color `#FDCC26`), iOS, web (manifest + favicon), Windows, and
macOS. Regenerate after replacing the source image with
`dart run flutter_launcher_icons`. Verified live: the emulator's launcher
shows the new icon and the "Chick Talk" label, and the in-app title/splash
text was updated to match (`lib/app/app.dart`, `lib/features/home/home_tab.dart`,
`lib/features/auth/splash_screen.dart`).

**Not changed**: the underlying package/application identifiers
(`com.walkietalkie.walkie_talkie` on Android, matching on iOS/macOS) and the
Dart package name (`walkie_talkie` in `pubspec.yaml`) are unchanged — those
are a separate, harder-to-reverse decision (an app's store identifier is
effectively permanent once published) and are worth deciding deliberately
before Phase 10 release prep, not as a side effect of a rebrand.

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
| Actual audio connectivity between peers | 🟡 Signaling confirmed live cross-country (Japan↔India); direct audio failed without TURN as expected — TURN relay now wired, pending re-verification — see caveat |
| Notifications: friend request/accept, channel-join alerts, read/unread inbox | ✅ Real (Supabase Postgres + RPCs) — verified live |
| Notification preferences: 6 global toggles + per-channel All/Important/Muted | ✅ Real, persisted (Settings → Notifications; channel header menu) |
| Actual push delivery to a device (FCM) | ⬜ Not wired — needs a Firebase project; `device_tokens` table is ready to receive tokens |
| Reconnection (network loss, dropped signaling channel, failed peer connection) | ✅ Real — exponential backoff, auto-retry — verified live |
| App lifecycle awareness (release mic on background, reconnect on resume) | ✅ Real (`WidgetsBindingObserver`) — verified live |
| Global offline banner | ✅ Real (`connectivity_plus`) — verified live |
| Audio output routing (auto-prefer Bluetooth, manual picker) | ✅ Real (`flutter_webrtc` `Helper`) — enumeration/picker verified live; real BT-device routing needs a physical device |

Every piece now lives behind a service class in [lib/services/](lib/services/),
each exposed as a Riverpod provider — `auth_service.dart`, `profile_service.dart`,
`friends_service.dart`, `channels_service.dart`, `webrtc_service.dart`,
`notifications_service.dart`, and `connectivity_service.dart` are all real now.
Nothing is left mocked except actual FCM push delivery (see Phase 6 section below).

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

**Verified live, twice, with two different outcomes:**

1. Sandbox → sandbox (Android emulator + an isolated headless Chrome
   instance): signaling confirmed working end to end (mic permission, "2
   online" presence, real SDP offer/answer exchange) but ICE never
   connected — STUN requests timed out on every interface, consistent with
   this dev sandbox blocking outbound UDP.
2. **Real phone → real phone, Japan ↔ India, different mobile carriers**:
   signaling again worked perfectly (channel joined by code, "transmitting"
   status visible both ways), but **no audio made it through in either
   direction** — the direct peer-to-peer connection never established.
   This is the expected result of STUN-only ICE against two carrier-grade
   or symmetric NATs, which STUN alone can't traverse — not a signaling bug,
   and not specific to this sandbox.

**TURN relay is now wired** (`TurnConfig`, `webrtc_service.dart`'s
`_fetchIceServers`) to fix exactly this: at call start, the app fetches a
short-lived TURN credential set from a configured provider (tested against
[Metered.ca](https://www.metered.ca/), free tier, no card required — see
setup below) and uses it as `iceServers`, so a direct connection can fall
back to relaying through the TURN server when NAT traversal fails. Any
failure to fetch credentials (not configured, network error, provider
down) degrades to the STUN-only fallback rather than breaking voice
outright. **Not yet re-verified with real TURN credentials on the same
Japan/India real-device setup that first exposed the problem** — that's
the next concrete test once a Metered account is set up.

### Bluetooth-aware audio routing (Phase 8)

`webrtc_service.dart` calls `flutter_webrtc`'s `Helper.setSpeakerphoneOnButPreferBluetooth()`
once the local mic stream is up, so a call defaults to a connected Bluetooth
device over the earpiece/speaker without any user action (spec §8). It also
listens for `navigator.mediaDevices.ondevicechange` and re-enumerates outputs
whenever a device attaches or detaches mid-call (e.g. a headset connecting
after the channel screen is already open). A new icon button in the channel
header ([lib/features/voice/audio_route_picker.dart](lib/features/voice/audio_route_picker.dart))
opens a sheet listing every enumerated output with an icon guessed from its
label (Bluetooth/speaker/wired headset/earpiece) and a checkmark on the
active one; picking one calls `Helper.selectAudioOutput(deviceId)`. All of
this is wrapped defensively — enumeration/selection are iOS/Android-only in
`flutter_webrtc`, so the button simply stays disabled (empty output list) on
platforms that don't support it, rather than crashing.

**Verified live**: on the Pixel 8 emulator, the button appeared enabled
after joining a channel, and opening it correctly listed the emulator's one
real output ("Speakerphone") with the matching speaker icon; selecting it
called through to `Helper.selectAudioOutput` without error. **The
auto-prefer-Bluetooth default and switching to an actual Bluetooth
device haven't been confirmed** — the emulator has no Bluetooth audio
hardware to enumerate, so that needs a real device with a paired Bluetooth
headset (see Phase 9 below).

### Device testing (Phase 9)

Spec §9 calls for testing across real Android/iOS devices and OS versions.
This machine is Windows-only with a single Android emulator (Pixel 8 / API
34) — there is no Mac, so iOS builds/testing are categorically impossible
here (`flutter doctor` doesn't even list an iOS toolchain to check), and no
physical Android hardware is attached either.

**What was actually done**: a full regression pass on the emulator across
every screen, after Phases 1–8 were all stacked together, to catch anything
one phase's changes broke in another — Home (online friends, channel list),
Friends (search/empty state), Settings (Light/Dark/System theme switching,
confirmed correct contrast in dark mode), Notifications inbox, and the
Channel screen (members, recent log, TALK button, the new audio-route
picker, and re-entering the channel repeatedly to rule out the
`autoDispose` WebRTC session leaking state across navigations). No crashes
or visual regressions found.

**What still needs real hardware, owned by whoever has access to it**:

- Any iOS testing at all (needs a Mac + Xcode + an Apple Developer account
  for a physical device, or at minimum a Simulator run).
- Real Android devices across a few manufacturers/OS versions — the
  emulator is a reasonable proxy for logic bugs but not for OEM quirks
  (background process killing being the big one for a voice app, plus
  actual Bluetooth hardware per the Phase 8 caveat above).
- Different physical screen sizes (small phones, tablets, foldables) —
  everything so far has only run at the Pixel 8's 1080×2400.

### Reconnection & resilience (Phase 7)

`webrtc_service.dart` now tracks connection health explicitly
(`VoiceConnectionState`: connecting/connected/reconnecting/lost) and reacts to
three kinds of disruption, per spec §19:

- **Network loss/regain** (`connectivity_service.dart`, wrapping
  `connectivity_plus`): losing all interfaces immediately marks the session
  `lost` and cancels any pending retry; regaining one resets the backoff and
  retries right away instead of waiting out the current delay.
- **Dropped signaling channel**: a Supabase Realtime `channelError`/
  `timedOut`/`closed` callback schedules a reconnect with exponential
  backoff (1s, 2s, 4s, ... capped at 30s), tearing down and rebuilding every
  peer connection and re-subscribing to `voice:{channelId}`.
- **One peer's connection failing** (`RTCPeerConnectionStateFailed`): only
  that peer's connection is torn down and re-negotiated (same offerer
  tie-break rule as initial connect); the rest of the session is undisturbed.

App lifecycle is also handled directly (`WidgetsBindingObserver`, not just a
widget-level check): backgrounding the app (`AppLifecycleState.paused`) stops
any in-progress transmission and releases the mic; returning to the
foreground (`resumed`) triggers an immediate reconnect if the session had
been lost or was mid-backoff. A thin app-wide banner
([lib/app/app.dart](lib/app/app.dart)) shows "No internet connection"
whenever `connectivity_plus` reports no interface up, independent of whether
a voice channel is even open. The channel screen's status line
([lib/features/channels/channel_screen.dart](lib/features/channels/channel_screen.dart))
now surfaces all four connection states (e.g. "🟡 Reconnecting..." / "🔴
Connection lost"), not just connected-vs-connecting.

**Verified live**: on the Pixel 8 emulator, disabling WiFi + mobile data
(`adb shell svc wifi disable` / `svc data disable`) while sitting in an
active channel immediately showed the "No internet connection" banner and
flipped the channel status line to "🟡 Reconnecting..."; re-enabling both
brought it straight back to "channel quiet" without waiting out the backoff
timer. Separately, holding TALK (confirmed via screenshot: "🎙 You are
transmitting" / button reading "TALKING") and then sending the device home
button — backgrounding the app without ever releasing the button — produced
a new entry in the RECENT transmissions log on the next foreground (e.g.
"QA_Tester · 0:14") even though no release gesture ever reached the app while
backgrounded; the only code path that can log a transmission is
`stopTalking()`, so this confirms `didChangeAppLifecycleState`'s `paused`
handler is what stopped it, not a coincidental release.

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
│   ├── voice/          # TALK button, audio output route picker
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

## One-time setup: TURN server (for real voice connectivity)

Without this, voice falls back to STUN-only, which **fails** whenever both
peers are behind a restrictive/symmetric NAT — confirmed live between two
real phones on different mobile carriers/countries (see the voice
architecture caveat above). Setting this up is what actually gets a call to
connect for most real users.

1. Sign up free at [dashboard.metered.ca/signup](https://dashboard.metered.ca/signup)
   (no credit card; free tier is 500MB/month TURN relay + unlimited STUN —
   plenty for testing and light real use).
2. Name your app when prompted; it drops you on the TURN Server page.
3. Click **"Click Here to Generate Your First Credential"** (or **Add
   Credential**) to create a credential.
4. You need two things from there:
   - Your app's TURN endpoint: `https://<your-app-name>.metered.live/api/v1/turn/credentials`
   - The **API Key** shown next to the credential (via "Show API Key") —
     this one is safe to embed client-side, it's scoped to that credential
     (Metered's "Secret Key" under Dashboard → Developers is the one to
     never expose — this app doesn't use that one).
5. Add both to `env.json`: `TURN_CREDENTIALS_URL` (the endpoint from step
   4, no query string) and `TURN_API_KEY`.

The app calls that endpoint once per voice session (`_fetchIceServers` in
`webrtc_service.dart`) and uses whatever it returns — STUN and TURN entries
together — as the ICE server list for every peer connection in that
session. Leaving `TURN_CREDENTIALS_URL`/`TURN_API_KEY` out of `env.json`
entirely is also fine: the app just runs STUN-only, same as before.

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
Phase 7 has also been verified live on the emulator — see the reconnection
& resilience section above for the specific scenarios tested. Phase 8 has
also been verified live on the emulator to the extent the emulator's
hardware allows — see the Bluetooth-aware audio routing section above.
Phase 9 is a full regression pass across every screen, also on the
emulator — see the device testing section above for exactly what that
covered and what it couldn't (real hardware, iOS).

## Next steps (later phases)

1. **Re-verify Phase 5 audio now that TURN is wired** — same real-device
   test that first exposed the problem (two phones, different
   networks/countries if possible, one holds TALK): confirm the other side
   now actually hears it. Needs a Metered account set up first (see TURN
   setup above).
2. **Wire actual push delivery (Phase 6)** — create a Firebase project, add
   `firebase_core`/`firebase_messaging` to the app, call
   `register_device_token` with the resulting FCM token, and add a Supabase
   Edge Function (triggered by a Database Webhook on `notifications`
   inserts) that calls the FCM HTTP v1 API to actually push to the stored
   tokens.
3. **Confirm Phase 8 Bluetooth routing on a real device** — pair a Bluetooth
   headset, join a channel, confirm the call routes to it automatically and
   that the picker sheet lists it and switches correctly.
4. **Finish Phase 9 on real hardware** — a few real Android devices/OS
   versions, a Mac to build and test iOS at all, and a couple of different
   physical screen sizes. None of this is possible on this machine.
5. Accessibility polish and store release prep (Phase 10, see below).
