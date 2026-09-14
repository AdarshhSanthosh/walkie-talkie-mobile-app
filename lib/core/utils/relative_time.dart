/// Formats a past [DateTime] as a short "Xm ago" / "Xh ago" / "Xd ago" label,
/// matching the "last heard 2m ago" style from the design reference.
String relativeTimeLabel(DateTime from, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(from);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/// Formats a [DateTime] as a 24h `HH:mm` clock label, matching the "14:02"
/// timestamps in the recent transmissions list.
String clockLabel(DateTime time) {
  final h = time.hour.toString().padLeft(2, '0');
  final m = time.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Formats a duration in seconds as `m:ss`, matching "0:06" in the recent
/// transmissions list.
String durationLabel(int totalSeconds) {
  final m = totalSeconds ~/ 60;
  final s = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
