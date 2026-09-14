import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../models/app_user.dart';
import '../../models/friend_request.dart';
import '../../models/presence_status.dart';
import '../../services/friends_service.dart';

/// Friends screen (spec §4): search + send requests, accept/reject
/// incoming requests, and manage existing friends (remove/block).
class FriendsTab extends ConsumerStatefulWidget {
  const FriendsTab({super.key});

  @override
  ConsumerState<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends ConsumerState<FriendsTab> {
  final _searchCtrl = TextEditingController();
  List<AppUser> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    final results = await ref.read(friendsRepositoryProvider).searchUsers(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
      refreshFriendsProviders(ref);
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }

  String _friendlyError(Object e) {
    final text = e.toString();
    final match = RegExp(r'message: ([^,]+)').firstMatch(text);
    return match?.group(1) ?? text;
  }

  @override
  Widget build(BuildContext context) {
    final incoming = ref.watch(incomingRequestsProvider).value ?? [];
    final friends = ref.watch(friendsListProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Find friends by name',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            onSubmitted: _search,
            onChanged: (v) {
              if (v.trim().isEmpty) setState(() => _results = []);
            },
          ),
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionLabel(context, 'RESULTS'),
            const SizedBox(height: 8),
            ..._results.map((u) => _SearchResultRow(
                  user: u,
                  onAdd: () => _runAction(() => ref.read(friendsRepositoryProvider).sendFriendRequest(u.id)),
                )),
          ],
          if (incoming.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionLabel(context, 'REQUESTS'),
            const SizedBox(height: 8),
            ...incoming.map((r) => _RequestRow(
                  request: r,
                  onAccept: () =>
                      _runAction(() => ref.read(friendsRepositoryProvider).acceptFriendRequest(r.id)),
                  onReject: () =>
                      _runAction(() => ref.read(friendsRepositoryProvider).rejectFriendRequest(r.id)),
                )),
          ],
          const SizedBox(height: 24),
          _sectionLabel(context, 'FRIENDS'),
          const SizedBox(height: 8),
          if (friends.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No friends yet — search above to add some.'),
            )
          else
            ...friends.map((f) => _FriendRow(
                  user: f,
                  onRemove: () => _runAction(() => ref.read(friendsRepositoryProvider).removeFriend(f.id)),
                  onBlock: () => _runAction(() => ref.read(friendsRepositoryProvider).blockUser(f.id)),
                )),
        ],
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

class _SearchResultRow extends StatelessWidget {
  final AppUser user;
  final VoidCallback onAdd;

  const _SearchResultRow({required this.user, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return _FriendCard(
      user: user,
      trailing: OutlinedButton(onPressed: onAdd, child: const Text('Add')),
    );
  }
}

class _RequestRow extends StatelessWidget {
  final FriendRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _RequestRow({required this.request, required this.onAccept, required this.onReject});

  @override
  Widget build(BuildContext context) {
    return _FriendCard(
      user: request.otherUser,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onAccept,
            icon: const Icon(Icons.check_circle, color: AppColors.green),
          ),
          IconButton(
            onPressed: onReject,
            icon: Icon(Icons.cancel, color: Theme.of(context).colorScheme.error),
          ),
        ],
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  final AppUser user;
  final VoidCallback onRemove;
  final VoidCallback onBlock;

  const _FriendRow({required this.user, required this.onRemove, required this.onBlock});

  @override
  Widget build(BuildContext context) {
    return _FriendCard(
      user: user,
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (v) {
          if (v == 'remove') onRemove();
          if (v == 'block') onBlock();
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'remove', child: Text('Remove friend')),
          PopupMenuItem(value: 'block', child: Text('Block')),
        ],
      ),
    );
  }
}

/// Shared row layout for search results / requests / friends.
class _FriendCard extends StatelessWidget {
  final AppUser user;
  final Widget trailing;

  const _FriendCard({required this.user, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
            child: user.avatarUrl == null ? Text(user.displayName[0]) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  '@${user.username}',
                  style: TextStyle(color: context.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          if (user.status == PresenceStatus.online)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.circle, size: 8, color: AppColors.green),
            ),
          trailing,
        ],
      ),
    );
  }
}
