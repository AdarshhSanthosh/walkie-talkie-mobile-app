import 'presence_status.dart';

/// A user profile (spec §3).
class AppUser {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final PresenceStatus status;
  final DateTime lastSeen;

  /// Whether this user is actively connected to the channel being viewed
  /// right now (shown as the "on channel" pill in the design reference),
  /// as opposed to merely being online elsewhere.
  final bool activeInChannel;

  const AppUser({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.status = PresenceStatus.offline,
    required this.lastSeen,
    this.activeInChannel = false,
  });

  AppUser copyWith({PresenceStatus? status}) => AppUser(
        id: id,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        status: status ?? this.status,
        lastSeen: lastSeen,
        activeInChannel: activeInChannel,
      );
}
