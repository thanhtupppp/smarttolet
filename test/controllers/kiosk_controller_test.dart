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

    test(
      'Triggering face detection initiates dispensing flow and sets cooldown',
      () async {
        const testFace = 'face_user_001';
        expect(controller.isUnderCooldown(testFace), isFalse);

        final future = controller.triggerFaceDetected(testFace);

        // Wait for completion
        await future;

        // Status should transition through dispensing to success
        expect(controller.status, equals(KioskStatus.success));
        expect(controller.isUnderCooldown(testFace), isTrue);
        expect(
          controller.getCooldownRemaining(testFace).inMinutes,
          greaterThan(0),
        );

        // Triggering again immediately should hit cooldown
        controller.resetToIdle();
        expect(controller.status, equals(KioskStatus.idle));

        await controller.triggerFaceDetected(testFace);
        expect(controller.status, equals(KioskStatus.cooldown));
      },
    );

    test(
      'Scanning the same face multiple times maintains original cooldown expiry and does not reset',
      () async {
        final testEmbedding = List.filled(192, 0.072); // Unit vector approx

        // Lần 1: Nhận giấy thành công
        await controller.triggerFaceDetected(
          'scan_1',
          embedding192d: testEmbedding,
        );
        expect(controller.status, equals(KioskStatus.success));

        final firstRemaining = controller.getCooldownRemaining('scan_1');
        expect(firstRemaining.inMinutes, greaterThan(0));

        // Lần 2 (100ms sau, dù faceId khác nhưng embedding giống nhau): Báo Cooldown và giữ nguyên mốc đếm
        controller.resetToIdle();
        await Future.delayed(const Duration(milliseconds: 100));
        await controller.triggerFaceDetected(
          'scan_2_different_seed',
          embedding192d: testEmbedding,
        );
        expect(controller.status, equals(KioskStatus.cooldown));

        final secondRemaining = controller.activeCooldownRemaining;
        expect(secondRemaining, isNotNull);
        expect(
          secondRemaining.inMilliseconds,
          lessThanOrEqualTo(firstRemaining.inMilliseconds),
        );

        // Lần 3 (dù faceId lại khác nữa): Vẫn báo Cooldown và thời gian đếm tiếp tục giảm
        controller.resetToIdle();
        await Future.delayed(const Duration(milliseconds: 100));
        await controller.triggerFaceDetected(
          'scan_3_yet_another_seed',
          embedding192d: testEmbedding,
        );
        expect(controller.status, equals(KioskStatus.cooldown));

        final thirdRemaining = controller.activeCooldownRemaining;
        expect(thirdRemaining, isNotNull);
        expect(
          thirdRemaining.inMilliseconds,
          lessThanOrEqualTo(secondRemaining.inMilliseconds),
        );
      },
    );

    test('resetToIdle resets state correctly', () {
      controller.resetToIdle();
      expect(controller.status, equals(KioskStatus.idle));
      expect(controller.activeFaceId, isNull);
    });
  });
}
