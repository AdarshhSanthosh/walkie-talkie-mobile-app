import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../services/webrtc_service.dart';

/// The big HOLD TO TRANSMIT button (spec §6), styled after the design
/// reference: a solid orange circle with faint concentric rings behind it,
/// "TALK" + a small caption inside.
///
/// Uses press-and-hold (onTapDown/onTapUp/onTapCancel) rather than a plain
/// tap, so releasing — including dragging off the button — always stops
/// transmission. Real mic-permission + WebRTC start/stop (Phase 5).
class TalkButton extends ConsumerWidget {
  final String channelId;

  const TalkButton({super.key, required this.channelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(webRtcServiceProvider(channelId));
    final notifier = ref.read(webRtcServiceProvider(channelId).notifier);
    final speaking = session.isTransmitting;

    return GestureDetector(
      onTapDown: (_) => notifier.startTalking(),
      onTapUp: (_) => notifier.stopTalking(),
      onTapCancel: () => notifier.stopTalking(),
      child: SizedBox(
        width: 220,
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _ring(200, speaking),
            _ring(240, speaking),
            AnimatedScale(
              duration: const Duration(milliseconds: 120),
              scale: speaking ? 1.04 : 1.0,
              child: Container(
                width: 176,
                height: 176,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.orange,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.orange.withValues(alpha: speaking ? 0.55 : 0.35),
                      blurRadius: speaking ? 32 : 16,
                      spreadRadius: speaking ? 6 : 0,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      speaking ? 'TALKING' : 'TALK',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      speaking ? 'RELEASE TO SEND' : 'HOLD TO TRANSMIT',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ring(double size, bool speaking) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: speaking ? size + 16 : size,
      height: speaking ? size + 16 : size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.18), width: 1.5),
      ),
    );
  }
}
