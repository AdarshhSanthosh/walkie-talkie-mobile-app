/// Supabase project credentials, injected at build/run time via
/// `--dart-define-from-file=env.json` (see `env.example.json` and the
/// README) — never hardcoded, never committed.
class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
