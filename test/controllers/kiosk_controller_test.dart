import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_toilet_kiosk/controllers/kiosk_controller.dart';
import 'package:smart_toilet_kiosk/models/kiosk_state.dart';
import 'package:smart_toilet_kiosk/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KioskController Tests', () {
    late SettingsService settingsService;
    late KioskController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settingsService = await SettingsService.init();
      controller = KioskController(settingsService);
    });

    tearDown(() {
      controller.dispose();
    });

    test('Initial state is idle', () {
      expect(controller.status, equals(KioskStatus.idle));
      expect(controller.dispenseProgress, equals(0.0));
      expect(controller.currentDispensedCm, equals(0));
    });

    test('Triggering face detection initiates dispensing flow and sets cooldown', () async {
      const testFace = 'face_user_001';
      expect(controller.isUnderCooldown(testFace), isFalse);

      final future = controller.triggerFaceDetected(testFace);
      
      // Wait for completion
      await future;

      // Status should transition through dispensing to success
      expect(controller.status, equals(KioskStatus.success));
      expect(controller.isUnderCooldown(testFace), isTrue);
      expect(controller.getCooldownRemaining(testFace).inMinutes, greaterThan(0));

      // Triggering again immediately should hit cooldown
      controller.resetToIdle();
      expect(controller.status, equals(KioskStatus.idle));

      await controller.triggerFaceDetected(testFace);
      expect(controller.status, equals(KioskStatus.cooldown));
    });

    test('resetToIdle resets state correctly', () {
      controller.resetToIdle();
      expect(controller.status, equals(KioskStatus.idle));
      expect(controller.activeFaceId, isNull);
    });
  });
}
