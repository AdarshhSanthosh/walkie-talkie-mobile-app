/// One row in the "Recent" transmissions list (design reference: speaker,
/// time, duration).
class TransmissionLogEntry {
  final String id;
  final String speakerName;
  final DateTime time;
  final int durationSeconds;

  const TransmissionLogEntry({
    required this.id,
    required this.speakerName,
    required this.time,
    required this.durationSeconds,
  });
}
