import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fake auth service for Phase 1.
///
/// Phase 2 replaces this with a Supabase-backed implementation behind the
/// same `isLoggedIn` / `signIn` / `signOut` surface, so screens never need to
/// change.
class AuthService extends Notifier<bool> {
  @override
  bool build() => false;

  bool get isLoggedIn => state;

  /// Accepts any non-empty credentials — Phase 2 will call Supabase Auth here.
  Future<bool> signIn({required String email, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (email.trim().isEmpty || password.trim().isEmpty) return false;
    state = true;
    return true;
  }

  Future<void> signInWithGoogle() async {
    await Future.delayed(const Duration(milliseconds: 400));
    state = true;
  }

  Future<void> signInWithApple() async {
    await Future.delayed(const Duration(milliseconds: 400));
    state = true;
  }

  void signOut() => state = false;
}

final authServiceProvider = NotifierProvider<AuthService, bool>(AuthService.new);
