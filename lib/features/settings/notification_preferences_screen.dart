import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/notification_preferences.dart';
import '../../services/notifications_service.dart';

/// Settings → Notifications (spec §10): global per-category toggles.
class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(notificationPreferencesProvider);
    final prefs = prefsAsync.value ?? const NotificationPreferences();

    Future<void> update(NotificationPreferences next) async {
      await ref.read(notificationsRepositoryProvider).updatePreferences(next);
      refreshNotificationsProviders(ref);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Friend Requests'),
            value: prefs.friendRequests,
            onChanged: (v) => update(prefs.copyWith(friendRequests: v)),
          ),
          SwitchListTile(
            title: const Text('Channel Invitations'),
            value: prefs.channelInvitations,
            onChanged: (v) => update(prefs.copyWith(channelInvitations: v)),
          ),
          SwitchListTile(
            title: const Text('Mentions'),
            value: prefs.mentions,
            onChanged: (v) => update(prefs.copyWith(mentions: v)),
          ),
          SwitchListTile(
            title: const Text('Announcements'),
            subtitle: const Text('E.g. someone joining a channel you own'),
            value: prefs.announcements,
            onChanged: (v) => update(prefs.copyWith(announcements: v)),
          ),
          SwitchListTile(
            title: const Text('Voice Activity'),
            subtitle: const Text('Off by default — voice transmissions are not meant to spam you'),
            value: prefs.voiceActivity,
            onChanged: (v) => update(prefs.copyWith(voiceActivity: v)),
          ),
          SwitchListTile(
            title: const Text('Direct Messages'),
            value: prefs.directMessages,
            onChanged: (v) => update(prefs.copyWith(directMessages: v)),
          ),
        ],
      ),
    );
  }
}
