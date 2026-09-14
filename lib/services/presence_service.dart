import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/presence_status.dart';

/// Fake presence service for Phase 1 — a static snapshot of friend presence,
/// modeled on the Maya / Theo / Ravi example in the design reference.
///
/// Phase 2+ replaces this with a Supabase Realtime (or Firebase RTDB)
/// subscription that updates `status`/`lastSeen` live.
class PresenceService {
  List<AppUser> get friends => _friends;

  static final _friends = <AppUser>[
    AppUser(
      id: 'u1',
      username: 'maya',
      displayName: 'Maya',
      avatarUrl: 'https://i.pravatar.cc/150?img=47',
      status: PresenceStatus.online,
      lastSeen: DateTime.now().subtract(const Duration(minutes: 2)),
      activeInChannel: true,
    ),
    AppUser(
      id: 'u2',
      username: 'theo',
      displayName: 'Theo',
      avatarUrl: 'https://i.pravatar.cc/150?img=12',
      status: PresenceStatus.online,
      lastSeen: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    AppUser(
      id: 'u3',
      username: 'ravi',
      displayName: 'Ravi',
      avatarUrl: 'https://i.pravatar.cc/150?img=53',
      status: PresenceStatus.offline,
      lastSeen: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];
}

final presenceServiceProvider = Provider<PresenceService>((ref) => PresenceService());

final friendsProvider = Provider<List<AppUser>>(
  (ref) => ref.watch(presenceServiceProvider).friends,
);

final onlineCountProvider = Provider<int>(
  (ref) => ref.watch(friendsProvider).where((f) => f.status == PresenceStatus.online).length,
);
