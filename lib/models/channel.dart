/// Channel privacy modes (spec §5).
enum ChannelPrivacy { public, private, friendsOnly, temporary }

extension ChannelPrivacyX on ChannelPrivacy {
  String get label => switch (this) {
        ChannelPrivacy.public => 'Public',
        ChannelPrivacy.private => 'Private',
        ChannelPrivacy.friendsOnly => 'Friends Only',
        ChannelPrivacy.temporary => 'Temporary',
      };
}

/// Roles within a channel (spec §5).
enum ChannelRole { owner, admin, moderator, member }

/// A voice channel (spec §5, §12).
class VoiceChannel {
  final String id;
  final String name;
  final String description;
  final String ownerId;
  final ChannelPrivacy privacy;
  final int maxMembers;
  final int memberCount;
  final String emoji;
  final String? inviteCode;

  const VoiceChannel({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerId,
    required this.privacy,
    required this.maxMembers,
    required this.memberCount,
    this.emoji = '📻',
    this.inviteCode,
  });
}
