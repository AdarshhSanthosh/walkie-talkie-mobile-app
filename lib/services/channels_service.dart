import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/app_user.dart';
import '../models/channel.dart';
import '../models/channel_member.dart';
import '../models/presence_status.dart';
import 'auth_service.dart';

/// Real Supabase-backed channels repository (Phase 4, spec §5).
///
/// Channel creation, joining, leaving, member removal, and deletion all go
/// through Postgres RPCs (see supabase/channels_schema.sql) so role checks
/// are enforced server-side, not trusted from the client.
class ChannelsRepository {
  sb.SupabaseClient get _client => sb.Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  Future<List<VoiceChannel>> fetchMyChannels() async {
    final uid = _uid;
    if (uid == null) return [];

    final memberships = await _client.from('channel_members').select('channel_id').eq('user_id', uid);
    final ids = (memberships as List).map((r) => r['channel_id'] as String).toList();
    if (ids.isEmpty) return [];

    final channelRows = await _client.from('channels').select().inFilter('id', ids);
    final counts = await _memberCounts(ids);

    return (channelRows as List)
        .map((r) => _channelFromRow(r as Map<String, dynamic>, counts[r['id']] ?? 0))
        .toList();
  }

  Future<VoiceChannel?> fetchChannel(String channelId) async {
    final row = await _client.from('channels').select().eq('id', channelId).maybeSingle();
    if (row == null) return null;
    final counts = await _memberCounts([channelId]);
    return _channelFromRow(row, counts[channelId] ?? 0);
  }

  Future<List<ChannelMember>> fetchMembers(String channelId) async {
    final rows = await _client
        .from('channel_members')
        .select('user_id, role, muted, banned, joined_at, profiles(*)')
        .eq('channel_id', channelId)
        .order('joined_at');
    return (rows as List).map((r) => _memberFromRow(r as Map<String, dynamic>)).toList();
  }

  Future<String> createChannel({
    required String name,
    required String description,
    required ChannelPrivacy privacy,
    required int maxMembers,
  }) async {
    final id = await _client.rpc('create_channel', params: {
      'p_name': name,
      'p_description': description,
      'p_privacy': _privacyToString(privacy),
      'p_max_members': maxMembers,
    });
    return id as String;
  }

  Future<String> joinByCode(String code) async {
    final id = await _client.rpc('join_channel_by_code', params: {'p_invite_code': code});
    return id as String;
  }

  Future<void> leaveChannel(String channelId) =>
      _client.rpc('leave_channel', params: {'p_channel_id': channelId});

  Future<void> removeMember(String channelId, String targetUserId) => _client.rpc(
        'remove_channel_member',
        params: {'p_channel_id': channelId, 'p_target_user_id': targetUserId},
      );

  Future<void> deleteChannel(String channelId) =>
      _client.rpc('delete_channel', params: {'p_channel_id': channelId});

  Future<Map<String, int>> _memberCounts(List<String> channelIds) async {
    final rows = await _client.from('channel_members').select('channel_id').inFilter('channel_id', channelIds);
    final counts = <String, int>{};
    for (final r in rows as List) {
      final id = r['channel_id'] as String;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  VoiceChannel _channelFromRow(Map<String, dynamic> row, int memberCount) => VoiceChannel(
        id: row['id'] as String,
        name: row['name'] as String,
        description: row['description'] as String? ?? '',
        ownerId: row['owner_id'] as String,
        privacy: _privacyFromString(row['privacy'] as String),
        maxMembers: row['max_members'] as int,
        memberCount: memberCount,
        emoji: row['avatar_emoji'] as String? ?? '📻',
        inviteCode: row['invite_code'] as String?,
      );

  ChannelMember _memberFromRow(Map<String, dynamic> row) => ChannelMember(
        userId: row['user_id'] as String,
        role: ChannelRole.values.byName(row['role'] as String),
        muted: row['muted'] as bool? ?? false,
        banned: row['banned'] as bool? ?? false,
        joinedAt: DateTime.parse(row['joined_at'] as String),
        profile: _userFromProfileRow(row['profiles'] as Map<String, dynamic>),
      );

  AppUser _userFromProfileRow(Map<String, dynamic> row) => AppUser(
        id: row['user_id'] as String,
        username: row['username'] as String,
        displayName: row['display_name'] as String,
        avatarUrl: row['avatar_url'] as String?,
        status: _statusFromString(row['status'] as String?),
        lastSeen: DateTime.tryParse(row['last_seen'] as String? ?? '') ?? DateTime.now(),
      );

  PresenceStatus _statusFromString(String? s) => switch (s) {
        'online' => PresenceStatus.online,
        'away' => PresenceStatus.away,
        'dnd' => PresenceStatus.doNotDisturb,
        _ => PresenceStatus.offline,
      };

  String _privacyToString(ChannelPrivacy p) => switch (p) {
        ChannelPrivacy.public => 'public',
        ChannelPrivacy.private => 'private',
        ChannelPrivacy.friendsOnly => 'friends_only',
        ChannelPrivacy.temporary => 'temporary',
      };

  ChannelPrivacy _privacyFromString(String s) => switch (s) {
        'public' => ChannelPrivacy.public,
        'friends_only' => ChannelPrivacy.friendsOnly,
        'temporary' => ChannelPrivacy.temporary,
        _ => ChannelPrivacy.private,
      };
}

final channelsRepositoryProvider = Provider<ChannelsRepository>((ref) => ChannelsRepository());

final myChannelsProvider = FutureProvider<List<VoiceChannel>>((ref) {
  ref.watch(authServiceProvider);
  return ref.watch(channelsRepositoryProvider).fetchMyChannels();
});

final channelProvider = FutureProvider.family<VoiceChannel?, String>((ref, channelId) {
  return ref.watch(channelsRepositoryProvider).fetchChannel(channelId);
});

final channelMembersProvider = FutureProvider.family<List<ChannelMember>, String>((ref, channelId) {
  return ref.watch(channelsRepositoryProvider).fetchMembers(channelId);
});

/// Refreshes channel providers — call after create/join/leave/remove/delete.
void refreshChannelsProviders(WidgetRef ref, {String? channelId}) {
  ref.invalidate(myChannelsProvider);
  if (channelId != null) {
    ref.invalidate(channelProvider(channelId));
    ref.invalidate(channelMembersProvider(channelId));
  }
}
