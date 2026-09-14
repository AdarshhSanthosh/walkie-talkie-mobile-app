import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Real Supabase-backed auth service (Phase 2).
///
/// Replaces the Phase 1 fake in-memory implementation behind the same
/// `isLoggedIn` surface, so screens didn't need to change. Every method
/// returns an error message string on failure, or `null` on success — this
/// keeps call sites simple without needing to catch exceptions themselves.
class AuthService extends Notifier<bool> {
  sb.GoTrueClient get _auth => sb.Supabase.instance.client.auth;

  @override
  bool build() {
    final sub = _auth.onAuthStateChange.listen((data) {
      state = data.session != null;
    });
    ref.onDispose(sub.cancel);
    return _auth.currentSession != null;
  }

  bool get isLoggedIn => state;

  /// Returns `null` on success, or a user-facing error message.
  Future<String?> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithPassword(email: email.trim(), password: password);
      return null;
    } on sb.AuthException catch (e) {
      return e.message;
    }
  }

  /// Creates a new account. If the Supabase project has email confirmation
  /// enabled (the default), the session stays null until the user confirms
  /// via the emailed link — [needsEmailConfirmation] on the result tells the
  /// caller which happened.
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final res = await _auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'display_name': displayName,
          'username': displayName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_'),
        },
      );
      return SignUpResult(needsEmailConfirmation: res.session == null);
    } on sb.AuthException catch (e) {
      return SignUpResult(error: e.message);
    }
  }

  /// Requires the Google provider to be enabled in the Supabase dashboard
  /// (Authentication → Providers) plus platform redirect-URL setup —
  /// returns a clear error message until that's configured.
  Future<String?> signInWithGoogle() => _oauth(sb.OAuthProvider.google);

  /// Requires the Apple provider to be enabled in the Supabase dashboard —
  /// same caveat as [signInWithGoogle].
  Future<String?> signInWithApple() => _oauth(sb.OAuthProvider.apple);

  Future<String?> _oauth(sb.OAuthProvider provider) async {
    try {
      await _auth.signInWithOAuth(provider);
      return null;
    } on sb.AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> signOut() => _auth.signOut();
}

class SignUpResult {
  final bool needsEmailConfirmation;
  final String? error;

  const SignUpResult({this.needsEmailConfirmation = false, this.error});

  bool get isSuccess => error == null;
}

final authServiceProvider = NotifierProvider<AuthService, bool>(AuthService.new);
