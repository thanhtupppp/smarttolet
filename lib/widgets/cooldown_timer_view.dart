import 'package:flutter/material.dart';
import '../theme/kiosk_theme.dart';

class CooldownTimerView extends StatelessWidget {
  final Duration remaining;
  final int totalCooldownMinutes;

  const CooldownTimerView({
    super.key,
    required this.remaining,
    this.totalCooldownMinutes = 9,
  });

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final totalSeconds = (totalCooldownMinutes * 60).toDouble();
    final remainingSeconds = remaining.inSeconds.toDouble().clamp(0.0, totalSeconds);
    final progress = totalSeconds > 0 ? (remainingSeconds / totalSeconds) : 0.0;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: KioskTheme.glowBox(
        glowColor: KioskTheme.warningAmber,
        radius: 28,
        bgColor: KioskTheme.surfaceElevated.withValues(alpha: 0.95),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Warning header tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: KioskTheme.warningAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: KioskTheme.warningAmber.withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hourglass_top_rounded, color: KioskTheme.warningAmber, size: 20),
                SizedBox(width: 8),
                Text(
                  'THỜI GIAN CHỜ (COOLDOWN)',
                  style: TextStyle(
                    color: KioskTheme.warningAmber,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Circular countdown clock
          SizedBox(
            width: 170,
            height: 170,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background circle
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 10,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      KioskTheme.surface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                // Glowing countdown indicator
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    strokeCap: StrokeCap.round,
                    valueColor: const AlwaysStoppedAnimation<Color>(KioskTheme.warningAmber),
                  ),
                ),
                // Time Text
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, color: KioskTheme.warningAmber, size: 24),
                    const SizedBox(height: 4),
                    Text(
                      _formatDuration(remaining),
                      style: const TextStyle(
                        color: KioskTheme.textPrimary,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Text(
                      'Phút : Giây',
                      style: TextStyle(
                        color: KioskTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Message
          const Text(
            'BẠN ĐÃ NHẬN GIẤY GẦN ĐÂY',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: KioskTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Để chống lãng phí, mỗi lượt cách nhau một khoảng thời gian quy định.\nVui lòng quay lại sau khi hết đồng hồ đếm ngược.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: KioskTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
