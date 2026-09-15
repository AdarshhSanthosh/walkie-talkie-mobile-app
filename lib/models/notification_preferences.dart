/// Global notification toggles (spec §10).
class NotificationPreferences {
  final bool friendRequests;
  final bool channelInvitations;
  final bool mentions;
  final bool announcements;
  final bool voiceActivity;
  final bool directMessages;

  const NotificationPreferences({
    this.friendRequests = true,
    this.channelInvitations = true,
    this.mentions = true,
    this.announcements = true,
    this.voiceActivity = false,
    this.directMessages = true,
  });

  NotificationPreferences copyWith({
    bool? friendRequests,
    bool? channelInvitations,
    bool? mentions,
    bool? announcements,
    bool? voiceActivity,
    bool? directMessages,
  }) {
    return NotificationPreferences(
      friendRequests: friendRequests ?? this.friendRequests,
      channelInvitations: channelInvitations ?? this.channelInvitations,
      mentions: mentions ?? this.mentions,
      announcements: announcements ?? this.announcements,
      voiceActivity: voiceActivity ?? this.voiceActivity,
      directMessages: directMessages ?? this.directMessages,
    );
  }
}

/// Per-channel mute level (spec §10).
enum ChannelNotificationLevel { all, important, muted }

extension ChannelNotificationLevelX on ChannelNotificationLevel {
  String get label => switch (this) {
        ChannelNotificationLevel.all => 'All Notifications',
        ChannelNotificationLevel.important => 'Important Only',
        ChannelNotificationLevel.muted => 'Muted',
      };

  String get dbValue => switch (this) {
        ChannelNotificationLevel.all => 'all',
        ChannelNotificationLevel.important => 'important',
        ChannelNotificationLevel.muted => 'muted',
      };

  static ChannelNotificationLevel fromDb(String s) => switch (s) {
        'important' => ChannelNotificationLevel.important,
        'muted' => ChannelNotificationLevel.muted,
        _ => ChannelNotificationLevel.all,
      };
}
