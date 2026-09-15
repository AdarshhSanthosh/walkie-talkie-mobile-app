import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/channel.dart';
import '../../models/presence_status.dart';
import '../../services/channels_service.dart';
import '../../services/friends_service.dart';
import '../../services/notifications_service.dart';
import '../../services/profile_service.dart';

/// Home screen (spec §11): greeting, online friends preview, channel list,
/// create/join-channel entry points. Friends (Phase 3) and channels
/// (Phase 4) are both real Supabase data now.
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsListProvider).value ?? [];
    final onlineFriends = friends.where((f) => f.status == PresenceStatus.online).toList();
    final channels = ref.watch(myChannelsProvider).value ?? [];
    final profile = ref.watch(profileServiceProvider);
    final name = profile.value?.displayName ?? '';
    final unread = ref.watch(unreadNotificationCountProvider).value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chick Talk'),
        actions: [
          IconButton(
            onPressed: () => context.push('/notifications'),
            icon: Badge(
              label: Text('$unread'),
              isLabelVisible: unread > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            name.isEmpty ? _greeting() : '${_greeting()}, $name',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          Text('Online Friends', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (onlineFriends.isEmpty)
            const Text('No friends online right now.')
          else
            ...onlineFriends.map(
              (f) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text(f.displayName[0])),
                title: Text(f.displayName),
                trailing: Text(f.status.emoji),
              ),
            ),
          const SizedBox(height: 24),
          Text('My Channels', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (channels.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No channels yet — create one or join with a code.'),
            )
          else
            ...channels.map(
              (c) => Card(
                child: ListTile(
                  leading: Text(c.emoji, style: const TextStyle(fontSize: 24)),
                  title: Text(c.name),
                  subtitle: Text('${c.memberCount} members · ${c.privacy.label}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/channel/${c.id}'),
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push('/create-channel'),
            icon: const Icon(Icons.add),
            label: const Text('CREATE CHANNEL'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/join-channel'),
            icon: const Icon(Icons.qr_code),
            label: const Text('JOIN WITH A CODE'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
          ),
        ],
      ),
    );
  }
}
