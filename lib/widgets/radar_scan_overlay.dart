import 'package:flutter/material.dart';
import '../theme/kiosk_theme.dart';

class RadarScanOverlay extends StatefulWidget {
  final bool isFaceDetected;
  final String statusText;
  final Color activeColor;

  const RadarScanOverlay({
    super.key,
    this.isFaceDetected = false,
    this.statusText = 'VUI LÒNG NHÌN VÀO CAMERA',
    this.activeColor = KioskTheme.primaryCyan,
  });

  @override
  State<RadarScanOverlay> createState() => _RadarScanOverlayState();
}

class _RadarScanOverlayState extends State<RadarScanOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxSize = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth * 0.75
            : constraints.maxHeight * 0.75;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Dark vignette around camera frame
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.85,
                  colors: [
                    Colors.transparent,
                    KioskTheme.background.withValues(alpha: 0.7),
                    KioskTheme.background.withValues(alpha: 0.95),
                  ],
                ),
              ),
            ),

            // Face Target Frame
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: boxSize,
              height: boxSize * 1.25,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: widget.isFaceDetected
                      ? widget.activeColor
                      : KioskTheme.primaryCyan.withValues(alpha: 0.4),
                  width: widget.isFaceDetected ? 2.5 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.isFaceDetected
                        ? widget.activeColor.withValues(alpha: 0.35)
                        : KioskTheme.primaryCyan.withValues(alpha: 0.1),
                    blurRadius: widget.isFaceDetected ? 24 : 12,
                    spreadRadius: widget.isFaceDetected ? 2 : 0,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Corner target indicators
                  _buildCorner(Alignment.topLeft),
                  _buildCorner(Alignment.topRight),
                  _buildCorner(Alignment.bottomLeft),
                  _buildCorner(Alignment.bottomRight),

                  // Scanning Laser Line
                  AnimatedBuilder(
                    animation: _scanAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: (boxSize * 1.25) * _scanAnimation.value,
                        left: 12,
                        right: 12,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                widget.activeColor,
                                Colors.white,
                                widget.activeColor,
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: widget.activeColor,
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Status message badge below scanner
            Positioned(
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: KioskTheme.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: widget.activeColor.withValues(alpha: 0.5),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isFaceDetected ? Icons.face_retouching_natural : Icons.center_focus_strong,
                      color: widget.activeColor,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.statusText,
                      style: TextStyle(
                        color: KioskTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCorner(Alignment alignment) {
    const size = 28.0;
    const thickness = 4.0;
    final color = widget.isFaceDetected ? widget.activeColor : KioskTheme.primaryCyan;

    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border(
            top: (alignment == Alignment.topLeft || alignment == Alignment.topRight)
                ? BorderSide(color: color, width: thickness)
                : BorderSide.none,
            bottom: (alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight)
                ? BorderSide(color: color, width: thickness)
                : BorderSide.none,
            left: (alignment == Alignment.topLeft || alignment == Alignment.bottomLeft)
                ? BorderSide(color: color, width: thickness)
                : BorderSide.none,
            right: (alignment == Alignment.topRight || alignment == Alignment.bottomRight)
                ? BorderSide(color: color, width: thickness)
                : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: alignment == Alignment.topLeft ? const Radius.circular(16) : Radius.zero,
            topRight: alignment == Alignment.topRight ? const Radius.circular(16) : Radius.zero,
            bottomLeft: alignment == Alignment.bottomLeft ? const Radius.circular(16) : Radius.zero,
            bottomRight: alignment == Alignment.bottomRight ? const Radius.circular(16) : Radius.zero,
          ),
        ),
      ),
    );
  }
}
