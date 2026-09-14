import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/relative_time.dart';
import '../../../models/transmission_log_entry.dart';

/// One row in the "RECENT" transmissions list (design reference): time,
/// speaker, a small waveform glyph, and duration.
class TransmissionRow extends StatelessWidget {
  final TransmissionLogEntry entry;

  const TransmissionRow({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(
            clockLabel(entry.time),
            style: TextStyle(color: context.textMuted, fontSize: 13),
          ),
          const SizedBox(width: 12),
          Text(entry.speakerName, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          const _Waveform(),
          const Spacer(),
          Text(
            durationLabel(entry.durationSeconds),
            style: TextStyle(color: context.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// A tiny static bar-chart glyph standing in for a waveform icon.
class _Waveform extends StatelessWidget {
  const _Waveform();

  static const _heights = [6.0, 12.0, 8.0, 14.0];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final h in _heights)
            Container(
              width: 2.5,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}
