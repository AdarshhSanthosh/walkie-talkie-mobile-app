import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/voice_connection_state.dart';
import 'transmission_log_service.dart';

/// Fake push-to-talk controller for Phase 1.
///
/// Mirrors the flow in spec §6 (press → check permission → acquire mic →
/// start WebRTC audio → transmit → release → stop) minus any real audio.
/// Phase 5 replaces `_startTransmitting` / `_stopTransmitting` with real
/// `flutter_webrtc` + signaling calls behind this same notifier.
class VoiceSessionState {
  final VoiceConnectionState connection;
  final bool isTransmitting;
  final String? speakerName;

  const VoiceSessionState({
    this.connection = VoiceConnectionState.connected,
    this.isTransmitting = false,
    this.speakerName,
  });

  VoiceSessionState copyWith({
    VoiceConnectionState? connection,
    bool? isTransmitting,
    String? speakerName,
    bool clearSpeaker = false,
  }) {
    return VoiceSessionState(
      connection: connection ?? this.connection,
      isTransmitting: isTransmitting ?? this.isTransmitting,
      speakerName: clearSpeaker ? null : (speakerName ?? this.speakerName),
    );
  }
}

class WebRtcService extends Notifier<VoiceSessionState> {
  DateTime? _talkStartedAt;

  @override
  VoiceSessionState build() => const VoiceSessionState();

  /// Simulates: permission check → channel membership → speaking lock →
  /// acquire mic → start transmitting.
  Future<void> startTalking({required String displayName}) async {
    if (state.isTransmitting || state.speakerName != null) return; // lock held
    HapticFeedback.mediumImpact();
    _talkStartedAt = DateTime.now();
    state = state.copyWith(isTransmitting: true, speakerName: displayName);
  }

  Future<void> stopTalking() async {
    if (!state.isTransmitting) return;
    HapticFeedback.lightImpact();
    final startedAt = _talkStartedAt;
    final speaker = state.speakerName;
    state = state.copyWith(isTransmitting: false, clearSpeaker: true);
    if (startedAt != null && speaker != null) {
      final seconds = DateTime.now().difference(startedAt).inSeconds;
      ref.read(transmissionLogServiceProvider.notifier).logTransmission(
            speakerName: speaker,
            durationSeconds: seconds,
          );
    }
    _talkStartedAt = null;
  }
}

final webRtcServiceProvider =
    NotifierProvider<WebRtcService, VoiceSessionState>(WebRtcService.new);
