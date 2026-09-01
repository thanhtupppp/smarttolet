import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/kiosk_theme.dart';

class PaperDispenseAnimation extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final int currentCm;
  final int targetCm;
  final bool isCompleted;

  const PaperDispenseAnimation({
    super.key,
    required this.progress,
    required this.currentCm,
    required this.targetCm,
    this.isCompleted = false,
  });

  @override
  State<PaperDispenseAnimation> createState() => _PaperDispenseAnimationState();
}

class _PaperDispenseAnimationState extends State<PaperDispenseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _spinController.repeat();
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.isCompleted ? KioskTheme.accentGreen : KioskTheme.primaryCyan;
    final pctText = (widget.progress * 100).clamp(0, 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: KioskTheme.glowBox(
        glowColor: activeColor,
        radius: 28,
        bgColor: KioskTheme.surfaceElevated.withValues(alpha: 0.9),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: activeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: activeColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isCompleted ? Icons.check_circle_rounded : Icons.sync_rounded,
                  color: activeColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.isCompleted ? '✓ ĐÃ CẤP GIẤY THÀNH CÔNG' : '🧻 ĐANG CẤP GIẤY TỰ ĐỘNG...',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: activeColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Animated Paper Roll & Ribbon
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Unspooling Paper Ribbon
                Positioned(
                  top: 45,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 100,
                    height: (52 + (widget.progress * 68)).clamp(52.0, 120.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Paper perforations
                        Container(
                          height: 2,
                          color: Colors.grey.shade400,
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        ),
                        // Dispensed length text printed on paper
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${widget.currentCm} cm',
                            style: const TextStyle(
                              color: Color(0xFF334155),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Rotating Paper Roll Cylinder Top
                AnimatedBuilder(
                  animation: _spinController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: widget.isCompleted ? 0 : _spinController.value * 2 * math.pi,
                      child: Container(
                        width: 110,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: activeColor.withValues(alpha: 0.3),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF94A3B8),
                              border: Border.all(color: const Color(0xFF475569), width: 2),
                            ),
                            child: Center(
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Big Counter Display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${widget.currentCm}',
                style: TextStyle(
                  color: activeColor,
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/ ${widget.targetCm} cm',
                style: const TextStyle(
                  color: KioskTheme.textSecondary,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 12,
              child: LinearProgressIndicator(
                value: widget.progress.clamp(0.0, 1.0),
                backgroundColor: KioskTheme.surface,
                valueColor: AlwaysStoppedAnimation<Color>(activeColor),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Progress % and note
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.isCompleted ? 'Hoàn tất 100%' : 'Tiến độ: $pctText%',
                style: const TextStyle(
                  color: KioskTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                widget.isCompleted ? 'Vui lòng nhận giấy ở khay dưới' : 'Motor đang chạy...',
                style: TextStyle(
                  color: widget.isCompleted ? KioskTheme.accentGreen : KioskTheme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
