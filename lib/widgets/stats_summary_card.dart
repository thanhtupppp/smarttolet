import 'package:flutter/material.dart';
import '../theme/kiosk_theme.dart';

class StatsSummaryCard extends StatelessWidget {
  final int todayUses;
  final String todayMeters;
  final double remainingPercentage;
  final VoidCallback onResetRoll;

  const StatsSummaryCard({
    super.key,
    required this.todayUses,
    required this.todayMeters,
    required this.remainingPercentage,
    required this.onResetRoll,
  });

  @override
  Widget build(BuildContext context) {
    Color rollColor = KioskTheme.accentGreen;
    if (remainingPercentage < 15) {
      rollColor = KioskTheme.errorRed;
    } else if (remainingPercentage < 35) {
      rollColor = KioskTheme.warningAmber;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: KioskTheme.glowBox(
        glowColor: KioskTheme.primaryCyan,
        radius: 20,
        bgColor: KioskTheme.surfaceElevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics_outlined, color: KioskTheme.primaryCyan, size: 22),
              SizedBox(width: 8),
              Text(
                'THỐNG KÊ HOẠT ĐỘNG',
                style: TextStyle(
                  color: KioskTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3 Metric Cards in Row
          Row(
            children: [
              // Metric 1: Today Uses
              Expanded(
                child: _buildMetricItem(
                  icon: Icons.person_pin_circle_outlined,
                  color: KioskTheme.primaryCyan,
                  title: 'Lượt hôm nay',
                  value: '$todayUses',
                  unit: 'lượt',
                ),
              ),
              const SizedBox(width: 12),
              // Metric 2: Today Meters
              Expanded(
                child: _buildMetricItem(
                  icon: Icons.straighten_outlined,
                  color: KioskTheme.purpleNeon,
                  title: 'Đã cấp hôm nay',
                  value: todayMeters,
                  unit: 'mét',
                ),
              ),
              const SizedBox(width: 12),
              // Metric 3: Roll Remaining
              Expanded(
                child: _buildMetricItem(
                  icon: Icons.battery_charging_full_rounded,
                  color: rollColor,
                  title: 'Giấy trong cuộn',
                  value: '${remainingPercentage.toStringAsFixed(0)}%',
                  unit: 'ước tính',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Roll remaining progress bar & Reset button
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (remainingPercentage / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: KioskTheme.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(rollColor),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              OutlinedButton.icon(
                onPressed: onResetRoll,
                icon: const Icon(Icons.refresh_rounded, size: 16, color: KioskTheme.primaryCyan),
                label: const Text(
                  'Thay cuộn mới',
                  style: TextStyle(fontSize: 12, color: KioskTheme.primaryCyan),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  side: const BorderSide(color: KioskTheme.primaryCyan, width: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KioskTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 18),
              Text(
                unit,
                style: const TextStyle(color: KioskTheme.textMuted, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: KioskTheme.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
