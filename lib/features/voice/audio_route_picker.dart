import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../app/theme.dart';
import '../../services/webrtc_service.dart';

/// Audio output route picker (spec §8): a small icon button that reflects
/// the current route (Bluetooth/speaker/earpiece/wired) and opens a sheet
/// to switch it manually. The session already defaults to a connected
/// Bluetooth device automatically — this is for overriding that choice.
class AudioRouteButton extends ConsumerWidget {
  final String channelId;

  const AudioRouteButton({super.key, required this.channelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(webRtcServiceProvider(channelId));
    final active = session.audioOutputs.where((d) => d.deviceId == session.activeAudioOutputId).firstOrNull;

    return IconButton(
      tooltip: active?.label ?? 'Audio output',
      icon: Icon(_iconFor(active?.label), size: 22),
      onPressed: session.audioOutputs.isEmpty
          ? null
          : () => _openPicker(context, ref, session.audioOutputs, session.activeAudioOutputId),
    );
  }

  void _openPicker(
    BuildContext context,
    WidgetRef ref,
    List<MediaDeviceInfo> outputs,
    String? activeId,
  ) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'AUDIO OUTPUT',
                  style: TextStyle(
                    color: sheetContext.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            for (final device in outputs)
              ListTile(
                leading: Icon(_iconFor(device.label), color: AppColors.orange),
                title: Text(device.label),
                trailing: device.deviceId == activeId ? const Icon(Icons.check, color: AppColors.orange) : null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ref.read(webRtcServiceProvider(channelId).notifier).setAudioOutput(device.deviceId);
                },
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String? label) {
    final l = label?.toLowerCase() ?? '';
    if (l.contains('bluetooth')) return Icons.bluetooth_audio;
    if (l.contains('speaker')) return Icons.volume_up;
    if (l.contains('wired') || l.contains('headset') || l.contains('headphone')) return Icons.headset;
    if (l.contains('earpiece') || l.contains('receiver')) return Icons.hearing;
    return Icons.speaker_phone;
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
