import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transmission_log_entry.dart';

/// Fake "Recent" transmissions log for Phase 1 — seeded with mock history,
/// with new entries prepended as the local user talks.
///
/// Phase 5+ replaces this with a real per-channel transmission history
/// backed by the voice session service.
class TransmissionLogService extends Notifier<List<TransmissionLogEntry>> {
  @override
  List<TransmissionLogEntry> build() {
    final now = DateTime.now();
    return [
      TransmissionLogEntry(
        id: 't1',
        speakerName: 'Maya',
        time: now.subtract(const Duration(hours: 1, minutes: 20)),
        durationSeconds: 6,
      ),
      TransmissionLogEntry(
        id: 't2',
        speakerName: 'Theo',
        time: now.subtract(const Duration(hours: 1, minutes: 34)),
        durationSeconds: 11,
      ),
      TransmissionLogEntry(
        id: 't3',
        speakerName: 'Maya',
        time: now.subtract(const Duration(hours: 2, minutes: 25)),
        durationSeconds: 4,
      ),
    ];
  }

  void logTransmission({required String speakerName, required int durationSeconds}) {
    final entry = TransmissionLogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      speakerName: speakerName,
      time: DateTime.now(),
      durationSeconds: durationSeconds,
    );
    state = [entry, ...state];
  }
}

final transmissionLogServiceProvider =
    NotifierProvider<TransmissionLogService, List<TransmissionLogEntry>>(
  TransmissionLogService.new,
);
