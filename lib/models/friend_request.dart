import 'app_user.dart';

/// Friend request states (spec §4). `removed` and `blocked` aren't stored
/// on the request row itself — they're modeled by `friendships` /
/// `blocked_users` rows disappearing/appearing instead.
enum FriendRequestStatus { pending, accepted, rejected }

/// A friend request row, joined with whichever profile is "the other
/// person" relative to the current user (spec §4).
class FriendRequest {
  final String id;
  final String senderId;
  final String receiverId;
  final FriendRequestStatus status;
  final DateTime createdAt;
  final AppUser otherUser;

  const FriendRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    required this.otherUser,
  });
}
