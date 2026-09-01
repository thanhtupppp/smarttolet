import 'package:flutter/material.dart';
import '../theme/kiosk_theme.dart';
import 'radar_scan_overlay.dart';

class CameraMockView extends StatelessWidget {
  final bool isFaceDetected;
  final String statusText;
  final Color activeColor;
  final VoidCallback? onMockFaceTap;

  const CameraMockView({
    super.key,
    this.isFaceDetected = false,
    this.statusText = 'VUI LÒNG NHÌN VÀO CAMERA',
    this.activeColor = KioskTheme.primaryCyan,
    this.onMockFaceTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onMockFaceTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: activeColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Camera Lens Mockup
              _buildCameraBackground(),

              // Grid overlay
              _buildGridOverlay(),

              // Radar Scan and Target Framing Overlay
              RadarScanOverlay(
                isFaceDetected: isFaceDetected,
                statusText: statusText,
                activeColor: activeColor,
              ),

              // Camera lens indicator top badge
              Positioned(
                top: 16,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24, width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFaceDetected ? KioskTheme.accentGreen : KioskTheme.primaryCyan,
                          boxShadow: [
                            BoxShadow(
                              color: isFaceDetected ? KioskTheme.accentGreen : KioskTheme.primaryCyan,
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isFaceDetected ? 'AI: KHUÔN MẶT ĐÃ KHÓA' : 'CAMERA HOẠT ĐỘNG',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Interactive helper badge on bottom right
              if (onMockFaceTap != null && !isFaceDetected)
                Positioned(
                  top: 16,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: KioskTheme.primaryCyan.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: KioskTheme.primaryCyan.withValues(alpha: 0.4), width: 0.5),
                    ),
                    child: const Text(
                      'CHẠM ĐỂ MÔ PHỎNG MẶT',
                      style: TextStyle(
                        color: KioskTheme.primaryCyan,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
            Color(0xFF0A0F1D),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person_outline_rounded,
          size: 220,
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
    );
  }

  Widget _buildGridOverlay() {
    return Opacity(
      opacity: 0.04,
      child: CustomPaint(
        painter: _GridPainter(),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
