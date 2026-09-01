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
              const SizedBox(height: 16),

              // Main Interactive Center Viewport
              Expanded(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _buildStateView(context, controller),
                  ),
                ),
              ),
              const SizedBox(height: 16),

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
          onRealFaceDetected: (faceInfo) {
            controller.triggerFaceDetected(
              faceInfo.faceFeatureSeed,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          Text(
            'Định mức: ${controller.config.paperLengthCm}cm  •  Cooldown: ${controller.config.cooldownMinutes} phút  •  AI Camera Tự Động',
            style: const TextStyle(
              color: KioskTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
