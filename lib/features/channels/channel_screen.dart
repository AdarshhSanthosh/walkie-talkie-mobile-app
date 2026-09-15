import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../app/theme.dart';
import '../../models/channel.dart';
import '../../models/channel_member.dart';
import '../../models/notification_preferences.dart';
import '../../models/voice_connection_state.dart';
import '../../services/channels_service.dart';
import '../../services/notifications_service.dart';
import '../../services/transmission_log_service.dart';
import '../../services/webrtc_service.dart';
import '../voice/talk_button.dart';
import 'widgets/member_row.dart';
import 'widgets/transmission_row.dart';

/// Channel screen, styled after the design reference
/// (https://friend-chatterbox.lovable.app): header with online count,
/// a FRIENDS list, a RECENT transmissions log, and the big TALK button.
/// Channel + membership are real Supabase data (Phase 4).
class ChannelScreen extends ConsumerWidget {
  final String channelId;

  const ChannelScreen({super.key, required this.channelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channel = ref.watch(channelProvider(channelId)).value;
    final members = ref.watch(channelMembersProvider(channelId)).value ?? [];
    final session = ref.watch(webRtcServiceProvider(channelId));
    // Real-time voice presence (who's actually connected right now) is a
    // more accurate "online" count than the static `profiles.status`
    // column, which nothing updates yet.
    final onlineCount = session.peerCount + (session.connection != VoiceConnectionState.lost ? 1 : 0);
    final recent = ref.watch(transmissionLogServiceProvider);
    final myUid = sb.Supabase.instance.client.auth.currentUser?.id;
    final myMembership = members.where((m) => m.userId == myUid).firstOrNull;
    final myRole = myMembership?.role;

    if (channel == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    Future<void> changeNotificationLevel(ChannelNotificationLevel level) async {
      await ref.read(notificationsRepositoryProvider).setChannelNotificationLevel(channelId, level);
      refreshChannelsProviders(ref, channelId: channelId);
    }

    Future<void> removeMember(ChannelMember m) async {
      try {
        await ref.read(channelsRepositoryProvider).removeMember(channelId, m.userId);
        refreshChannelsProviders(ref, channelId: channelId);
      } on Object catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
      }
    }

    Future<void> leaveOrDelete(bool isOwner) async {
      try {
        final repo = ref.read(channelsRepositoryProvider);
        if (isOwner) {
          await repo.deleteChannel(channelId);
        } else {
          await repo.leaveChannel(channelId);
        }
        refreshChannelsProviders(ref, channelId: channelId);
        if (!context.mounted) return;
        context.go('/home');
      } on Object catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              channel: channel,
              onlineCount: onlineCount,
              isOwner: myRole == ChannelRole.owner,
              onLeaveOrDelete: () => leaveOrDelete(myRole == ChannelRole.owner),
              notificationLevel: myMembership?.notificationLevel ?? ChannelNotificationLevel.all,
              onChangeNotificationLevel: changeNotificationLevel,
            ),
            const SizedBox(height: 4),
            Text(
              session.speakerName != null
                  ? (session.speakerName == 'You'
                      ? '🎙 You are transmitting'
                      : '🎙 ${session.speakerName} is transmitting')
                  : (session.connection == VoiceConnectionState.connected
                      ? 'channel quiet'
                      : session.connection.label),
              style: TextStyle(color: context.textMuted, fontSize: 13),
            ),
            if (session.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  session.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _sectionLabel(context, 'MEMBERS'),
                  const SizedBox(height: 8),
                  for (final m in members)
                    MemberRow(
                      member: m.profile,
                      role: m.role,
                      onRemove: (myRole == ChannelRole.owner || myRole == ChannelRole.admin) &&
                              m.userId != channel.ownerId &&
                              m.userId != myUid
                          ? () => removeMember(m)
                          : null,
                    ),
                  const SizedBox(height: 8),
                  _sectionLabel(context, 'RECENT'),
                  const SizedBox(height: 8),
                  for (final t in recent) TransmissionRow(entry: t),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: TalkButton(channelId: channelId),
            ),
          ],
        ),
      ),
    );
  }

  String _friendlyError(Object e) {
    final text = e.toString();
    final match = RegExp(r'message: ([^,]+)').firstMatch(text);
    return match?.group(1) ?? text;
  }

  Widget _sectionLabel(BuildContext context, String text) => Text(
        text,
        style: TextStyle(
          color: context.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      );
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _Header extends StatelessWidget {
  final VoiceChannel channel;
  final int onlineCount;
  final bool isOwner;
  final VoidCallback onLeaveOrDelete;
  final ChannelNotificationLevel notificationLevel;
  final ValueChanged<ChannelNotificationLevel> onChangeNotificationLevel;

  const _Header({
    required this.channel,
    required this.onlineCount,
    required this.isOwner,
    required this.onLeaveOrDelete,
    required this.notificationLevel,
    required this.onChangeNotificationLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back),
          ),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.orange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              channel.name.isNotEmpty ? channel.name[0].toUpperCase() : '#',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(channel.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                Text(
                  channel.description.isNotEmpty ? channel.description : 'the group channel',
                  style: TextStyle(color: context.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, size: 8, color: AppColors.green),
                const SizedBox(width: 6),
                Text('$onlineCount online', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'leave_or_delete':
                  onLeaveOrDelete();
                case 'level_all':
                  onChangeNotificationLevel(ChannelNotificationLevel.all);
                case 'level_important':
                  onChangeNotificationLevel(ChannelNotificationLevel.important);
                case 'level_muted':
                  onChangeNotificationLevel(ChannelNotificationLevel.muted);
              }
            },
            itemBuilder: (context) => [
              for (final level in ChannelNotificationLevel.values)
                CheckedPopupMenuItem(
                  value: 'level_${level.name}',
                  checked: notificationLevel == level,
                  child: Text(level.label),
                ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'leave_or_delete',
                child: Text(isOwner ? 'Delete channel' : 'Leave channel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
