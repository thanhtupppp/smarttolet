import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/kiosk_controller.dart';
import '../models/kiosk_state.dart';
import '../theme/kiosk_theme.dart';
import '../widgets/live_camera_view.dart';
import '../widgets/paper_dispense_animation.dart';
import '../widgets/cooldown_timer_view.dart';
import '../widgets/hidden_trigger_button.dart';
import '../widgets/admin_pin_dialog.dart';
import 'admin_settings_screen.dart';

class KioskHomeScreen extends StatelessWidget {
  const KioskHomeScreen({super.key});

  void _openAdminPanel(BuildContext context) {
    final controller = context.read<KioskController>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AdminPinDialog(
          expectedPin: controller.config.adminPin,
          onSuccess: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminSettingsScreen()),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<KioskController>();

    return Scaffold(
      backgroundColor: KioskTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            children: [
              // Kiosk Top App Bar
              _buildTopBar(context, controller),
              const SizedBox(height: 10),

              // Real-Time AI Face Telemetry & Debug HUD
              _buildDebugHud(context, controller),
              const SizedBox(height: 10),

              // Main Interactive Center Viewport
              Expanded(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _buildStateView(context, controller),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Bottom Simulation / Control Tray
              _buildBottomControlBar(context, controller),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, KioskController controller) {
    final modeName = controller.config.connectionMode.name.toUpperCase();
    Color modeColor = KioskTheme.primaryCyan;
    if (controller.config.connectionMode == ConnectionMode.demo) {
      modeColor = KioskTheme.purpleNeon;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: KioskTheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo & App Name
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: KioskTheme.primaryCyan.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.wc_rounded, color: KioskTheme.primaryCyan, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'SMART TOILET',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: KioskTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        'CẤP GIẤY TỰ ĐỘNG',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: KioskTheme.textSecondary.withValues(alpha: 0.8),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Right: Connection Mode Badge & Hidden Admin Trigger (Hold 3s)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: modeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: modeColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  modeName,
                  style: TextStyle(
                    color: modeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Hidden Admin Button (Press & Hold for 3 seconds)
              HiddenTriggerButton(
                holdDuration: const Duration(seconds: 3),
                onTriggered: () => _openAdminPanel(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStateView(BuildContext context, KioskController controller) {
    switch (controller.status) {
      case KioskStatus.idle:
        return LiveCameraView(
          isFaceDetected: false,
          statusText: 'VUI LÒNG NHÌN VÀO CAMERA',
          activeColor: KioskTheme.primaryCyan,
          onFaceTrackingUpdate: (faceInfo) {
            controller.updateLiveTrackingDebug(
              trackingId: faceInfo.trackingId,
              leftEye: faceInfo.leftEyeOpen,
              rightEye: faceInfo.rightEyeOpen,
              seed: faceInfo.faceFeatureSeed,
            );
          },
          onRealFaceDetected: (faceInfo) {
            controller.triggerFaceDetected(
              faceInfo.faceFeatureSeed,
              embedding192d: faceInfo.embedding192d,
              trackingId: faceInfo.trackingId,
              boundingBoxRatio: faceInfo.boundingBoxRatio,
              eyeDistanceRatio: faceInfo.eyeDistanceRatio,
              mouthWidthRatio: faceInfo.mouthWidthRatio,
              noseToMouthRatio: faceInfo.noseToMouthRatio,
              eyeToNoseRatio: faceInfo.eyeToNoseRatio,
              cheekWidthRatio: faceInfo.cheekWidthRatio,
              faceSymmetryRatio: faceInfo.faceSymmetryRatio,
            );
          },
        );

      case KioskStatus.scanning:
        return LiveCameraView(
          isFaceDetected: true,
          statusText: 'ĐANG PHÂN TÍCH KHUÔN MẶT...',
          activeColor: KioskTheme.accentGreen,
        );

      case KioskStatus.dispensing:
        return PaperDispenseAnimation(
          progress: controller.dispenseProgress,
          currentCm: controller.currentDispensedCm,
          targetCm: controller.config.paperLengthCm,
          isCompleted: false,
        );

      case KioskStatus.success:
        return PaperDispenseAnimation(
          progress: 1.0,
          currentCm: controller.config.paperLengthCm,
          targetCm: controller.config.paperLengthCm,
          isCompleted: true,
        );

      case KioskStatus.cooldown:
        return CooldownTimerView(
          remaining: controller.activeCooldownRemaining,
          totalCooldownMinutes: controller.config.cooldownMinutes,
        );

      case KioskStatus.error:
        return Container(
          padding: const EdgeInsets.all(28),
          decoration: KioskTheme.glowBox(
            glowColor: KioskTheme.errorRed,
            radius: 28,
            bgColor: KioskTheme.surfaceElevated,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: KioskTheme.errorRed, size: 54),
              const SizedBox(height: 16),
              const Text(
                'LỖI THIẾT BỊ',
                style: TextStyle(
                  color: KioskTheme.errorRed,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                controller.errorMessage ?? 'Không thể kết nối bo mạch điều khiển!',
                textAlign: TextAlign.center,
                style: const TextStyle(color: KioskTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => controller.resetToIdle(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('THỬ LẠI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KioskTheme.errorRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildBottomControlBar(BuildContext context, KioskController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: KioskTheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_user_rounded, color: KioskTheme.accentGreen, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Định mức: ${controller.config.paperLengthCm}cm • Chờ: ${controller.config.cooldownMinutes}p • AI Tự Động',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: KioskTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugHud(BuildContext context, KioskController controller) {
    final hasData = controller.debugLastScannedFaceId != null;
    final isMatch = controller.debugVerdict?.contains('TRÙNG') == true;
    final isCooldown = controller.status == KioskStatus.cooldown;
    final verdictColor = isMatch || isCooldown ? KioskTheme.warningAmber : KioskTheme.accentGreen;

    final leftEyePct = controller.debugLeftEye != null
        ? '${(controller.debugLeftEye! * 100).round()}%'
        : '--';
    final rightEyePct = controller.debugRightEye != null
        ? '${(controller.debugRightEye! * 100).round()}%'
        : '--';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (hasData ? verdictColor : Colors.white24).withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (hasData ? verdictColor : Colors.transparent).withValues(alpha: 0.15),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Telemetry Title & Status Pill
          Row(
            children: [
              Icon(Icons.radar_rounded, color: verdictColor, size: 16),
              const SizedBox(width: 6),
              const Text(
                'AI FACE DEBUG TELEMETRY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: verdictColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: verdictColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  controller.debugVerdict?.contains('TRÙNG') == true
                      ? 'ĐÃ TRÙNG COOLDOWN'
                      : (controller.debugLastScannedFaceId != null ? 'KHÁCH MỚI' : 'CHỜ MẶT'),
                  style: TextStyle(
                    color: verdictColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Row 1: Face ID & Tracking ID & Eye Open Probs
          Row(
            children: [
              Expanded(
                child: Text(
                  'ID: ${controller.debugLastScannedFaceId ?? '---'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: KioskTheme.primaryCyan,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Track #${controller.debugLastTrackingId ?? '--'}  •  Mắt L: $leftEyePct | R: $rightEyePct',
                style: const TextStyle(
                  color: KioskTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),

          // Row 2: Match result & Cosine similarity
          Text(
            'Kết quả: ${controller.debugVerdict ?? 'Đang đợi khuôn mặt trong khung quét...'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: verdictColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
