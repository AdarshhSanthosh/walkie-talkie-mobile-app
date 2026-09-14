import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/presence_status.dart';
import '../../services/presence_service.dart';

/// Full friends list (spec §4). Phase 1: read-only list from mock presence
/// data. Phase 3 adds search, requests, remove, and block actions here.
class FriendsTab extends ConsumerWidget {
  const FriendsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: friends.length,
        itemBuilder: (context, i) {
          final f = friends[i];
          return ListTile(
            leading: CircleAvatar(child: Text(f.displayName[0])),
            title: Text(f.displayName),
            subtitle: Text('@${f.username}'),
            trailing: Text(f.status.emoji, style: const TextStyle(fontSize: 18)),
          );
        },
      ),
    );
  }
}
