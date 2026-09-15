import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/utils/relative_time.dart';
import '../../models/notification_item.dart';
import '../../services/notifications_service.dart';

/// Notifications inbox (spec §9/§13: `GET /notifications`,
/// `PATCH /notifications/:id/read`).
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationsProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: items.isEmpty
          ? const Center(child: Text('No notifications yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final n = items[i];
                return _NotificationRow(
                  item: n,
                  onTap: n.read
                      ? null
                      : () async {
                          await ref.read(notificationsRepositoryProvider).markRead(n.id);
                          refreshNotificationsProviders(ref);
                        },
                );
              },
            ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback? onTap;

  const _NotificationRow({required this.item, required this.onTap});

  IconData get _icon => switch (item.type) {
        NotificationType.friendRequest => Icons.person_add_alt_1,
        NotificationType.friendAccept => Icons.check_circle_outline,
        NotificationType.channelActivity => Icons.podcasts,
      };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: item.read ? Theme.of(context).cardTheme.color : context.pillBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(_icon, color: AppColors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(item.body, style: TextStyle(color: context.textMuted, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(
                    relativeTimeLabel(item.createdAt),
                    style: TextStyle(color: context.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (!item.read)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.orange),
              ),
          ],
        ),
      ),
    );
  }
}
