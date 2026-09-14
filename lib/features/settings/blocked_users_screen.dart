import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/friends_service.dart';

/// Settings → Security → Blocked users (spec §17, §20).
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedUsersProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Blocked Users')),
      body: blocked.isEmpty
          ? const Center(child: Text('No blocked users.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: blocked.length,
              itemBuilder: (context, i) {
                final u = blocked[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: u.avatarUrl != null ? NetworkImage(u.avatarUrl!) : null,
                      child: u.avatarUrl == null ? Text(u.displayName[0]) : null,
                    ),
                    title: Text(u.displayName),
                    subtitle: Text('@${u.username}'),
                    trailing: OutlinedButton(
                      onPressed: () async {
                        await ref.read(friendsRepositoryProvider).unblockUser(u.id);
                        refreshFriendsProviders(ref);
                      },
                      child: const Text('Unblock'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
