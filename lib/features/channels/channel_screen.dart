import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../models/channel.dart';
import '../../services/database_service.dart';
import '../../services/presence_service.dart';
import '../../services/transmission_log_service.dart';
import '../../services/webrtc_service.dart';
import '../voice/talk_button.dart';
import 'widgets/member_row.dart';
import 'widgets/transmission_row.dart';

/// Channel screen, styled after the design reference
/// (https://friend-chatterbox.lovable.app): header with online count,
/// a FRIENDS list, a RECENT transmissions log, and the big TALK button.
class ChannelScreen extends ConsumerWidget {
  final String channelId;

  const ChannelScreen({super.key, required this.channelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(databaseServiceProvider);
    VoiceChannel? channel;
    for (final c in channels) {
      if (c.id == channelId) {
        channel = c;
        break;
      }
    }
    final members = ref.watch(friendsProvider);
    final onlineCount = ref.watch(onlineCountProvider);
    final session = ref.watch(webRtcServiceProvider);
    final recent = ref.watch(transmissionLogServiceProvider);

    if (channel == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Channel not found')),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(channel: channel, onlineCount: onlineCount),
            const SizedBox(height: 4),
            Text(
              session.speakerName != null
                  ? (session.speakerName == 'You'
                      ? '🎙 You are transmitting'
                      : '🎙 ${session.speakerName} is transmitting')
                  : 'channel quiet',
              style: TextStyle(color: context.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _sectionLabel(context, 'FRIENDS'),
                  const SizedBox(height: 8),
                  for (final m in members) MemberRow(member: m),
                  const SizedBox(height: 8),
                  _sectionLabel(context, 'RECENT'),
                  const SizedBox(height: 8),
                  for (final t in recent) TransmissionRow(entry: t),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: TalkButton(displayName: 'You'),
            ),
          ],
        ),
      ),
    );
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

class _Header extends StatelessWidget {
  final VoiceChannel channel;
  final int onlineCount;

  const _Header({required this.channel, required this.onlineCount});

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
        ],
      ),
    );
  }
}
