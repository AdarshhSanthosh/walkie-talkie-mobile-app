import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/voice_connection_state.dart';
import 'profile_service.dart';
import 'transmission_log_service.dart';

const _iceServers = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ],
};

/// Push-to-talk voice session for one channel (Phase 5, spec §6/§7).
///
/// Architecture: a mesh of direct WebRTC connections — one per other peer
/// currently in the channel — signaled over a Supabase Realtime channel
/// (`voice:{channelId}`). Presence on that channel doubles as "who's
/// listening right now" and carries each peer's live `speaking` flag, which
/// is what drives [VoiceSessionState.speakerName] for every participant,
/// not just the local user. This is a small-group design (spec §7 calls
/// mesh fine for dev/testing groups); a production build with larger
/// channels would swap this for an SFU without changing the public API
/// below (`startTalking`/`stopTalking`).
class VoiceSessionState {
  final VoiceConnectionState connection;
  final bool isTransmitting;
  final String? speakerName;
  final int peerCount;
  final String? error;

  const VoiceSessionState({
    this.connection = VoiceConnectionState.connecting,
    this.isTransmitting = false,
    this.speakerName,
    this.peerCount = 0,
    this.error,
  });

  VoiceSessionState copyWith({
    VoiceConnectionState? connection,
    bool? isTransmitting,
    String? speakerName,
    bool clearSpeaker = false,
    int? peerCount,
    String? error,
    bool clearError = false,
  }) {
    return VoiceSessionState(
      connection: connection ?? this.connection,
      isTransmitting: isTransmitting ?? this.isTransmitting,
      speakerName: clearSpeaker ? null : (speakerName ?? this.speakerName),
      peerCount: peerCount ?? this.peerCount,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class WebRtcService extends Notifier<VoiceSessionState> {
  WebRtcService(this.channelId);

  final String channelId;

  sb.SupabaseClient get _client => sb.Supabase.instance.client;
  String get _myUid => _client.auth.currentUser!.id;

  sb.RealtimeChannel? _signal;
  MediaStream? _localStream;
  final Map<String, RTCPeerConnection> _peers = {};
  String _myName = 'You';
  DateTime? _talkStartedAt;
  bool _disposed = false;

  @override
  VoiceSessionState build() {
    ref.onDispose(_disposeAll);
    _init();
    return const VoiceSessionState(connection: VoiceConnectionState.connecting);
  }

  Future<void> _init() async {
    _myName = ref.read(profileServiceProvider).value?.displayName ?? 'You';

    final micStatus = await Permission.microphone.request();
    if (_disposed) return;
    if (!micStatus.isGranted) {
      state = state.copyWith(
        connection: VoiceConnectionState.lost,
        error: 'Microphone permission is required to talk.',
      );
      return;
    }

    try {
      _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = false; // muted until the user holds TALK
      }
    } on Object catch (e) {
      if (_disposed) return;
      state = state.copyWith(connection: VoiceConnectionState.lost, error: e.toString());
      return;
    }
    if (_disposed) return;

    _signal = _client.channel(
      'voice:$channelId',
      opts: sb.RealtimeChannelConfig(key: _myUid),
    );

    _signal!
      ..onBroadcast(event: 'signal', callback: _handleSignal)
      ..onPresenceSync((_) => _onPresenceChange())
      ..onPresenceJoin((payload) => _onPeerJoin(payload.key))
      ..onPresenceLeave((payload) => _onPeerLeave(payload.key))
      ..subscribe((status, error) async {
        if (_disposed) return;
        if (status == sb.RealtimeSubscribeStatus.subscribed) {
          await _signal!.track({'display_name': _myName, 'speaking': false});
        } else if (status == sb.RealtimeSubscribeStatus.channelError ||
            status == sb.RealtimeSubscribeStatus.timedOut) {
          state = state.copyWith(connection: VoiceConnectionState.lost);
        }
      });
  }

  void _onPeerJoin(String otherId) {
    if (otherId != _myUid && !_peers.containsKey(otherId) && _myUid.compareTo(otherId) > 0) {
      // Deterministic tie-break: the larger id always initiates, so
      // exactly one side offers per pair — no negotiation collisions.
      unawaited(_startConnection(otherId, isOfferer: true));
    }
    _onPresenceChange();
  }

  void _onPeerLeave(String otherId) {
    _peers.remove(otherId)?.close();
    _onPresenceChange();
  }

  void _onPresenceChange() {
    if (_signal == null) return;
    final states = _signal!.presenceState();
    String? speaking;
    var others = 0;
    for (final s in states) {
      if (s.key == _myUid) continue;
      others++;
      for (final p in s.presences) {
        if (p.payload['speaking'] == true) {
          speaking = p.payload['display_name'] as String? ?? 'Someone';
        }
      }
    }
    // Drop connections to peers no longer present.
    for (final key in _peers.keys.toList()) {
      if (states.every((s) => s.key != key)) {
        _peers.remove(key)?.close();
      }
    }
    state = state.copyWith(
      peerCount: others,
      speakerName: state.isTransmitting ? 'You' : speaking,
      clearSpeaker: !state.isTransmitting && speaking == null,
      connection: _peers.values.any((p) => p.connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected)
          ? VoiceConnectionState.connected
          : (others == 0 ? VoiceConnectionState.connected : VoiceConnectionState.connecting),
    );
  }

  Future<RTCPeerConnection> _ensurePeerConnection(String otherId) async {
    final existing = _peers[otherId];
    if (existing != null) return existing;

    final pc = await createPeerConnection(_iceServers);
    _peers[otherId] = pc;

    for (final track in _localStream!.getAudioTracks()) {
      await pc.addTransceiver(
        track: track,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendRecv),
      );
    }

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      unawaited(_signal?.sendBroadcastMessage(event: 'signal', payload: {
        'from': _myUid,
        'to': otherId,
        'kind': 'candidate',
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      }));
    };
    pc.onConnectionState = (_) => _onPresenceChange();

    return pc;
  }

  Future<void> _startConnection(String otherId, {required bool isOfferer}) async {
    final pc = await _ensurePeerConnection(otherId);
    if (!isOfferer) return;
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    await _signal?.sendBroadcastMessage(event: 'signal', payload: {
      'from': _myUid,
      'to': otherId,
      'kind': 'offer',
      'sdp': offer.sdp,
      'type': offer.type,
    });
  }

  Future<void> _handleSignal(Map<String, dynamic> payload) async {
    if (payload['to'] != _myUid) return;
    final from = payload['from'] as String;
    final kind = payload['kind'] as String;

    switch (kind) {
      case 'offer':
        final pc = await _ensurePeerConnection(from);
        await pc.setRemoteDescription(RTCSessionDescription(payload['sdp'] as String, payload['type'] as String));
        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        await _signal?.sendBroadcastMessage(event: 'signal', payload: {
          'from': _myUid,
          'to': from,
          'kind': 'answer',
          'sdp': answer.sdp,
          'type': answer.type,
        });
      case 'answer':
        final pc = _peers[from];
        await pc?.setRemoteDescription(RTCSessionDescription(payload['sdp'] as String, payload['type'] as String));
      case 'candidate':
        final pc = _peers[from];
        await pc?.addCandidate(RTCIceCandidate(
          payload['candidate'] as String?,
          payload['sdpMid'] as String?,
          payload['sdpMLineIndex'] as int?,
        ));
    }
  }

  /// Simulates: permission check (already done in [_init]) → verify channel
  /// membership (the caller only reaches this screen if a member) → check
  /// speaking lock → acquire microphone → start transmitting.
  Future<void> startTalking({String? displayName}) async {
    if (state.isTransmitting) return;
    if (state.speakerName != null && state.speakerName != 'You') return; // someone else has the lock

    HapticFeedback.mediumImpact();
    _talkStartedAt = DateTime.now();
    for (final track in _localStream?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      track.enabled = true;
    }
    state = state.copyWith(isTransmitting: true, speakerName: 'You');
    await _signal?.track({'display_name': _myName, 'speaking': true});
  }

  Future<void> stopTalking() async {
    if (!state.isTransmitting) return;
    HapticFeedback.lightImpact();
    for (final track in _localStream?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      track.enabled = false;
    }
    final startedAt = _talkStartedAt;
    state = state.copyWith(isTransmitting: false, clearSpeaker: true);
    await _signal?.track({'display_name': _myName, 'speaking': false});
    _talkStartedAt = null;
    if (startedAt != null) {
      final seconds = DateTime.now().difference(startedAt).inSeconds;
      ref.read(transmissionLogServiceProvider.notifier).logTransmission(
            speakerName: _myName,
            durationSeconds: seconds,
          );
    }
  }

  void _disposeAll() {
    _disposed = true;
    for (final pc in _peers.values) {
      pc.close();
    }
    _peers.clear();
    for (final track in _localStream?.getTracks() ?? const <MediaStreamTrack>[]) {
      track.stop();
    }
    _localStream?.dispose();
    unawaited(_signal?.unsubscribe());
  }
}

final webRtcServiceProvider =
    NotifierProvider.family.autoDispose<WebRtcService, VoiceSessionState, String>(WebRtcService.new);
