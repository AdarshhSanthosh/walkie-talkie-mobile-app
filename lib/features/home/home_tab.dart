import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/channel.dart';
import '../../models/presence_status.dart';
import '../../services/database_service.dart';
import '../../services/presence_service.dart';
import '../../services/profile_service.dart';

/// Home screen (spec §11): greeting, online friends preview, channel list,
/// create-channel entry point. Data is mocked via [presenceServiceProvider]
/// and [databaseServiceProvider] for Phase 1.
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
    final friends = ref.watch(friendsProvider);
    final onlineFriends = friends.where((f) => f.status == PresenceStatus.online).toList();
    final channels = ref.watch(databaseServiceProvider);
    final profile = ref.watch(profileServiceProvider);
    final name = profile.value?.displayName ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Walkie Talkie')),
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
        ],
      ),
    );
  }
}
