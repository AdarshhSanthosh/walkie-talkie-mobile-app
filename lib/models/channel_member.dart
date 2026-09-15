import 'app_user.dart';
import 'channel.dart';
import 'notification_preferences.dart';

/// A row in a channel's member list (spec §12 `channel_members`), joined
/// with the member's profile for display.
class ChannelMember {
  final String userId;
  final ChannelRole role;
  final bool muted;
  final bool banned;
  final DateTime joinedAt;
  final AppUser profile;
  final ChannelNotificationLevel notificationLevel;

  const ChannelMember({
    required this.userId,
    required this.role,
    required this.muted,
    required this.banned,
    required this.joinedAt,
    required this.profile,
    this.notificationLevel = ChannelNotificationLevel.all,
  });
}
