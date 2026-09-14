/// UI states for the push-to-talk voice connection (spec §6).
enum VoiceConnectionState { idle, connecting, connected, reconnecting, lost }

extension VoiceConnectionStateX on VoiceConnectionState {
  String get label => switch (this) {
        VoiceConnectionState.idle => 'Idle',
        VoiceConnectionState.connecting => 'Connecting...',
        VoiceConnectionState.connected => '🟢 Connected',
        VoiceConnectionState.reconnecting => '🟡 Reconnecting...',
        VoiceConnectionState.lost => '🔴 Connection lost',
      };
}
