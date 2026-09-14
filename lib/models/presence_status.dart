/// User presence states shown across the app (spec §3).
enum PresenceStatus { online, away, offline, doNotDisturb }

extension PresenceStatusX on PresenceStatus {
  String get emoji => switch (this) {
        PresenceStatus.online => '🟢',
        PresenceStatus.away => '🟡',
        PresenceStatus.offline => '⚫',
        PresenceStatus.doNotDisturb => '🔴',
      };

  String get label => switch (this) {
        PresenceStatus.online => 'Online',
        PresenceStatus.away => 'Away',
        PresenceStatus.offline => 'Offline',
        PresenceStatus.doNotDisturb => 'Do Not Disturb',
      };
}
