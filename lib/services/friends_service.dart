import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/app_user.dart';
import '../models/friend_request.dart';
import '../models/presence_status.dart';
import 'auth_service.dart';

/// Real Supabase-backed friends/blocking repository (Phase 3, spec §4).
///
/// Every state change (send/accept/reject/remove/block/unblock) goes
/// through a Postgres RPC (see supabase/friends_schema.sql) rather than a
/// raw table write — the server, not the client, decides what's allowed.
class FriendsRepository {
  sb.SupabaseClient get _client => sb.Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  Future<List<AppUser>> searchUsers(String query) async {
    final q = query.trim();
    final uid = _uid;
    if (q.isEmpty || uid == null) return [];
    final rows = await _client
        .from('profiles')
        .select()
        .ilike('display_name', '%$q%')
        .neq('user_id', uid)
        .limit(20);
    return (rows as List).map((r) => _userFromRow(r as Map<String, dynamic>)).toList();
  }

  Future<List<AppUser>> fetchFriends() async {
    final uid = _uid;
    if (uid == null) return [];
    final rows = await _client
        .from('friendships')
        .select(
          'user_id_a, user_id_b, '
          'a:profiles!friendships_user_id_a_fkey(*), '
          'b:profiles!friendships_user_id_b_fkey(*)',
        )
        .or('user_id_a.eq.$uid,user_id_b.eq.$uid');
    return (rows as List).map((row) {
      final isA = row['user_id_a'] == uid;
      final other = (isA ? row['b'] : row['a']) as Map<String, dynamic>;
      return _userFromRow(other);
    }).toList();
  }

  Future<List<FriendRequest>> fetchIncomingRequests() => _fetchRequests(
        column: 'receiver_id',
        otherKey: 'sender',
        embed: 'sender:profiles!friend_requests_sender_id_fkey(*)',
      );

  Future<List<FriendRequest>> fetchOutgoingRequests() => _fetchRequests(
        column: 'sender_id',
        otherKey: 'receiver',
        embed: 'receiver:profiles!friend_requests_receiver_id_fkey(*)',
      );

  Future<List<FriendRequest>> _fetchRequests({
    required String column,
    required String otherKey,
    required String embed,
  }) async {
    final uid = _uid;
    if (uid == null) return [];
    final rows = await _client
        .from('friend_requests')
        .select('*, $embed')
        .eq(column, uid)
        .eq('status', 'pending')
        .order('created_at');
    return (rows as List)
        .map((r) => _requestFromRow(r as Map<String, dynamic>, otherKey: otherKey))
        .toList();
  }

  Future<List<AppUser>> fetchBlockedUsers() async {
    final uid = _uid;
    if (uid == null) return [];
    final rows = await _client
        .from('blocked_users')
        .select('*, blocked:profiles!blocked_users_blocked_id_fkey(*)')
        .eq('blocker_id', uid);
    return (rows as List)
        .map((r) => _userFromRow(r['blocked'] as Map<String, dynamic>))
        .toList();
  }

  Future<void> sendFriendRequest(String targetUserId) =>
      _client.rpc('send_friend_request', params: {'target_user_id': targetUserId});

  Future<void> acceptFriendRequest(String requestId) =>
      _client.rpc('accept_friend_request', params: {'request_id': requestId});

  Future<void> rejectFriendRequest(String requestId) =>
      _client.rpc('reject_friend_request', params: {'request_id': requestId});

  Future<void> removeFriend(String otherUserId) =>
      _client.rpc('remove_friend', params: {'other_user_id': otherUserId});

  Future<void> blockUser(String targetUserId) =>
      _client.rpc('block_user', params: {'target_user_id': targetUserId});

  Future<void> unblockUser(String targetUserId) =>
      _client.rpc('unblock_user', params: {'target_user_id': targetUserId});

  AppUser _userFromRow(Map<String, dynamic> row) => AppUser(
        id: row['user_id'] as String,
        username: row['username'] as String,
        displayName: row['display_name'] as String,
        avatarUrl: row['avatar_url'] as String?,
        status: _statusFromString(row['status'] as String?),
        lastSeen: DateTime.tryParse(row['last_seen'] as String? ?? '') ?? DateTime.now(),
      );

  FriendRequest _requestFromRow(Map<String, dynamic> row, {required String otherKey}) =>
      FriendRequest(
        id: row['id'] as String,
        senderId: row['sender_id'] as String,
        receiverId: row['receiver_id'] as String,
        status: FriendRequestStatus.values.byName(row['status'] as String),
        createdAt: DateTime.parse(row['created_at'] as String),
        otherUser: _userFromRow(row[otherKey] as Map<String, dynamic>),
      );

  PresenceStatus _statusFromString(String? s) => switch (s) {
        'online' => PresenceStatus.online,
        'away' => PresenceStatus.away,
        'dnd' => PresenceStatus.doNotDisturb,
        _ => PresenceStatus.offline,
      };
}

final friendsRepositoryProvider = Provider<FriendsRepository>((ref) => FriendsRepository());

final friendsListProvider = FutureProvider<List<AppUser>>((ref) {
  ref.watch(authServiceProvider);
  return ref.watch(friendsRepositoryProvider).fetchFriends();
});

final incomingRequestsProvider = FutureProvider<List<FriendRequest>>((ref) {
  ref.watch(authServiceProvider);
  return ref.watch(friendsRepositoryProvider).fetchIncomingRequests();
});

final outgoingRequestsProvider = FutureProvider<List<FriendRequest>>((ref) {
  ref.watch(authServiceProvider);
  return ref.watch(friendsRepositoryProvider).fetchOutgoingRequests();
});

final blockedUsersProvider = FutureProvider<List<AppUser>>((ref) {
  ref.watch(authServiceProvider);
  return ref.watch(friendsRepositoryProvider).fetchBlockedUsers();
});

final onlineCountProvider = FutureProvider<int>((ref) async {
  final friends = await ref.watch(friendsListProvider.future);
  return friends.where((f) => f.status == PresenceStatus.online).length;
});

/// Refreshes every friends-related provider — call after a mutating action
/// (send/accept/reject/remove/block/unblock) so the UI reflects it.
void refreshFriendsProviders(WidgetRef ref) {
  ref.invalidate(friendsListProvider);
  ref.invalidate(incomingRequestsProvider);
  ref.invalidate(outgoingRequestsProvider);
  ref.invalidate(blockedUsersProvider);
}
