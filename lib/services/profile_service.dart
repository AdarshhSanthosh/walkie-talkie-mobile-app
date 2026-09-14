import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/app_user.dart';
import '../models/presence_status.dart';
import 'auth_service.dart';

/// Fetches the signed-in user's row from the `profiles` table (spec §12).
///
/// Re-fetches whenever [authServiceProvider] flips (sign in/out), so the UI
/// always reflects whoever is currently logged in.
class ProfileService extends AsyncNotifier<AppUser?> {
  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  @override
  Future<AppUser?> build() async {
    ref.watch(authServiceProvider);
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final row = await _client.from('profiles').select().eq('user_id', user.id).maybeSingle();
    if (row == null) return null;

    return AppUser(
      id: row['user_id'] as String,
      username: row['username'] as String,
      displayName: row['display_name'] as String,
      avatarUrl: row['avatar_url'] as String?,
      status: PresenceStatus.online,
      lastSeen: DateTime.now(),
    );
  }
}

final profileServiceProvider = AsyncNotifierProvider<ProfileService, AppUser?>(ProfileService.new);
