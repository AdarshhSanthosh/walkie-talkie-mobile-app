import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/relative_time.dart';
import '../../../models/app_user.dart';
import '../../../models/channel.dart';
import '../../../models/presence_status.dart';

/// One row in the channel's "FRIENDS" list (design reference): avatar with
/// an online-status dot, name, "last heard Xm ago", and a trailing state —
/// a role pill (owner/admin/mod), a plain online dot, or "offline".
///
/// [role] is the member's role in this channel (Phase 4); when it's above
/// `member`, its label replaces the plain online dot. [onRemove], when
/// non-null, adds a trailing "⋮ Remove" menu — pass it only when the
/// current user is allowed to remove this member.
class MemberRow extends StatelessWidget {
  final AppUser member;
  final ChannelRole? role;
  final VoidCallback? onRemove;

  const MemberRow({super.key, required this.member, this.role, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final isOffline = member.status == PresenceStatus.offline;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOffline ? context.cardMutedBg : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: member.avatarUrl != null
                    ? NetworkImage(member.avatarUrl!)
                    : null,
                child: member.avatarUrl == null ? Text(member.displayName[0]) : null,
              ),
              if (!isOffline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.green,
                      border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  'last heard ${relativeTimeLabel(member.lastSeen)}',
                  style: TextStyle(color: context.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          _trailing(context, isOffline),
          if (onRemove != null)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: context.textMuted),
              onSelected: (_) => onRemove!(),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'remove', child: Text('Remove from channel')),
              ],
            ),
        ],
      ),
    );
  }

  Widget _trailing(BuildContext context, bool isOffline) {
    if (isOffline) {
      return Text('offline', style: TextStyle(color: context.textMuted, fontSize: 13));
    }
    if (role != null && role != ChannelRole.member) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: context.pillBg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          role!.label,
          style: const TextStyle(color: AppColors.orange, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
    }
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.green),
    );
  }
}
