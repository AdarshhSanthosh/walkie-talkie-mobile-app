/// Optional TURN relay credentials (spec §7), injected at build/run time via
/// `--dart-define-from-file=env.json` (see `env.example.json` and the
/// README) — never hardcoded, never committed.
///
/// Without these, voice falls back to STUN-only: direct peer-to-peer
/// connections, which fail whenever both sides are behind a restrictive or
/// symmetric NAT — common on mobile carrier networks, and confirmed live
/// between two real phones on different continents/carriers (Phase 7.5).
/// A TURN server relays the audio when a direct connection can't be made.
class TurnConfig {
  /// The provider's credential-fetch endpoint, e.g. for Metered.ca:
  /// `https://<your-app-name>.metered.live/api/v1/turn/credentials`
  /// (no query string — the API key is appended at request time).
  static const credentialsUrl = String.fromEnvironment('TURN_CREDENTIALS_URL');
  static const apiKey = String.fromEnvironment('TURN_API_KEY');

  static bool get isConfigured => credentialsUrl.isNotEmpty && apiKey.isNotEmpty;
}
