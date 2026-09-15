import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/voice_connection_state.dart';
import 'connectivity_service.dart';
import 'profile_service.dart';
import 'transmission_log_service.dart';

const _iceServers = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ],
};

const _maxReconnectDelay = Duration(seconds: 30);

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
///
/// Phase 7 (spec §19) adds resilience: dropped signaling reconnects with
/// exponential backoff, a regained network connection triggers an
/// immediate retry, individual failed peer connections are re-established
/// without tearing down the whole session, and backgrounding the app
/// releases the mic (Android/iOS won't reliably keep it live in the
/// background without a foreground service, which this app doesn't run).
///
/// Phase 8 (spec §8) adds Bluetooth-aware audio routing: a call defaults to
/// a connected Bluetooth device over the earpiece/speaker when one is
/// available, the app listens for devices attaching/detaching mid-call and
/// re-enumerates, and the user can override the route manually.
class VoiceSessionState {
  final VoiceConnectionState connection;
  final bool isTransmitting;
  final String? speakerName;
  final int peerCount;
  final String? error;
  final List<MediaDeviceInfo> audioOutputs;
  final String? activeAudioOutputId;

  const VoiceSessionState({
    this.connection = VoiceConnectionState.connecting,
    this.isTransmitting = false,
    this.speakerName,
    this.peerCount = 0,
    this.error,
    this.audioOutputs = const [],
    this.activeAudioOutputId,
  });

  VoiceSessionState copyWith({
    VoiceConnectionState? connection,
    bool? isTransmitting,
    String? speakerName,
    bool clearSpeaker = false,
    int? peerCount,
    String? error,
    bool clearError = false,
    List<MediaDeviceInfo>? audioOutputs,
    String? activeAudioOutputId,
  }) {
    return VoiceSessionState(
      connection: connection ?? this.connection,
      isTransmitting: isTransmitting ?? this.isTransmitting,
      speakerName: clearSpeaker ? null : (speakerName ?? this.speakerName),
      peerCount: peerCount ?? this.peerCount,
      error: clearError ? null : (error ?? this.error),
      audioOutputs: audioOutputs ?? this.audioOutputs,
      activeAudioOutputId: activeAudioOutputId ?? this.activeAudioOutputId,
    );
  }
}

class WebRtcService extends Notifier<VoiceSessionState> with WidgetsBindingObserver {
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
  bool _wasOnline = true;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  @override
  VoiceSessionState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(_disposeAll);
    ref.listen(isOnlineProvider, (previous, next) => _onConnectivityChanged(next.value));
    _init();
    return const VoiceSessionState(connection: VoiceConnectionState.connecting);
  }

  // Intentionally not named `state`: that would shadow the Notifier's own
  // `state` property, which the method body below reads.
  @override
  // ignore: avoid_renaming_method_parameters
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    // Spec §19: respect background mic/networking restrictions — release
    // the mic rather than assume it stays live once backgrounded.
    if (lifecycleState == AppLifecycleState.paused) {
      unawaited(stopTalking());
    } else if (lifecycleState == AppLifecycleState.resumed) {
      if (state.connection == VoiceConnectionState.lost ||
          state.connection == VoiceConnectionState.reconnecting) {
        _reconnect();
      }
    }
  }

  void _onConnectivityChanged(bool? isOnline) {
    if (isOnline == null || isOnline == _wasOnline) return;
    _wasOnline = isOnline;
    if (!isOnline) {
      _reconnectTimer?.cancel();
      state = state.copyWith(connection: VoiceConnectionState.lost);
    } else if (state.connection == VoiceConnectionState.lost ||
        state.connection == VoiceConnectionState.reconnecting) {
      // Network's back — retry right away instead of waiting out backoff.
      _reconnectAttempts = 0;
      _reconnect();
    }
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

    _setupAudioRouting();
    _connectSignaling();
  }

  /// Best-effort audio routing (spec §8): prefer a connected Bluetooth
  /// device over the earpiece/speaker, and keep the output list current as
  /// devices attach/detach mid-call. Only iOS/Android support any of this
  /// in `flutter_webrtc`, so every call here is wrapped — on web/desktop
  /// (used during dev on this machine) these are no-ops, not crashes.
  void _setupAudioRouting() {
    unawaited(Helper.setSpeakerphoneOnButPreferBluetooth().catchError((_) {}));
    try {
      navigator.mediaDevices.ondevicechange = (_) => unawaited(_refreshAudioOutputs());
    } on Object {
      // Not supported on this platform — the manual picker just won't
      // refresh itself when a device attaches/detaches.
    }
    unawaited(_refreshAudioOutputs());
  }

  Future<void> _refreshAudioOutputs() async {
    if (_disposed) return;
    try {
      final outputs = await Helper.enumerateDevices('audiooutput');
      if (_disposed) return;
      state = state.copyWith(audioOutputs: outputs);
    } on Object {
      // Enumeration unsupported/unavailable here — leave the list as-is.
    }
  }

  /// Manually override the audio output route (e.g. from a picker sheet).
  /// The automatic Bluetooth preference in [_setupAudioRouting] only picks
  /// a default when the call starts; this lets the user switch mid-call.
  Future<void> setAudioOutput(String deviceId) async {
    try {
      await Helper.selectAudioOutput(deviceId);
      state = state.copyWith(activeAudioOutputId: deviceId);
    } on Object catch (e) {
      state = state.copyWith(error: 'Could not switch audio output: $e');
    }
  }

  void _connectSignaling() {
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
          _reconnectTimer?.cancel();
          _reconnectAttempts = 0;
          await _signal!.track({'display_name': _myName, 'speaking': false});
          _onPresenceChange();
        } else if (status == sb.RealtimeSubscribeStatus.channelError ||
            status == sb.RealtimeSubscribeStatus.timedOut ||
            status == sb.RealtimeSubscribeStatus.closed) {
          _scheduleReconnect();
        }
      });
  }

  /// Exponential backoff, capped at 30s (spec §19: "Retry → Retry → Retry
  /// → Connected", not a hot retry loop that hammers the server).
  void _scheduleReconnect() {
    if (_disposed) return;
    state = state.copyWith(connection: VoiceConnectionState.reconnecting);
    _reconnectTimer?.cancel();
    final delaySeconds = min(pow(2, _reconnectAttempts).toInt(), _maxReconnectDelay.inSeconds);
    _reconnectAttempts++;
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), _reconnect);
  }

  void _reconnect() {
    if (_disposed) return;
    state = state.copyWith(connection: VoiceConnectionState.reconnecting);
    for (final pc in _peers.values) {
      pc.close();
    }
    _peers.clear();
    unawaited(_signal?.unsubscribe());
    _connectSignaling();
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
    pc.onConnectionState = (connectionState) {
      _onPresenceChange();
      // A single peer's link failing shouldn't take down the whole
      // session — just re-establish that one connection if they're still
      // around (spec §19: recover from WebRTC failures).
      if (connectionState == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _peers.remove(otherId)?.close();
        final stillPresent = _signal?.presenceState().any((s) => s.key == otherId) ?? false;
        if (stillPresent && _myUid.compareTo(otherId) > 0) {
          unawaited(_startConnection(otherId, isOfferer: true));
        }
      }
    };

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
    WidgetsBinding.instance.removeObserver(this);
    _reconnectTimer?.cancel();
    try {
      navigator.mediaDevices.ondevicechange = null;
    } on Object {
      // Not supported on this platform — nothing to clear.
    }
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
