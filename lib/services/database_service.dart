import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/channel.dart';

/// Fake database service for Phase 1 — an in-memory list of channels.
///
/// Phase 2+ replaces this with a Supabase-backed repository (see spec §12
/// for the `channels` / `channel_members` schema this mirrors), behind the
/// same read/create surface.
class DatabaseService extends Notifier<List<VoiceChannel>> {
  @override
  List<VoiceChannel> build() => [
        const VoiceChannel(
          id: 'c1',
          name: 'Friends',
          description: 'The main crew',
          ownerId: 'me',
          privacy: ChannelPrivacy.friendsOnly,
          maxMembers: 20,
          memberCount: 8,
        ),
        const VoiceChannel(
          id: 'c2',
          name: 'Gaming',
          description: 'Squad up',
          ownerId: 'me',
          privacy: ChannelPrivacy.private,
          maxMembers: 10,
          memberCount: 4,
        ),
        const VoiceChannel(
          id: 'c3',
          name: 'Family',
          description: 'Family channel',
          ownerId: 'me',
          privacy: ChannelPrivacy.private,
          maxMembers: 12,
          memberCount: 5,
        ),
      ];

  VoiceChannel? byId(String id) {
    for (final c in state) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Creates a channel locally and returns it with a generated invite code.
  /// Phase 2+ will POST to `/channels` (spec §13) instead.
  VoiceChannel createChannel({
    required String name,
    required String description,
    required ChannelPrivacy privacy,
    required int maxMembers,
  }) {
    final channel = VoiceChannel(
      id: 'c${state.length + 1}_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      ownerId: 'me',
      privacy: privacy,
      maxMembers: maxMembers,
      memberCount: 1,
      inviteCode: _generateInviteCode(),
    );
    state = [...state, channel];
    return channel;
  }

  static String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}

final databaseServiceProvider =
    NotifierProvider<DatabaseService, List<VoiceChannel>>(DatabaseService.new);
