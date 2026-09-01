import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_toilet_kiosk/controllers/kiosk_controller.dart';
import 'package:smart_toilet_kiosk/screens/kiosk_home_screen.dart';
import 'package:smart_toilet_kiosk/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('KioskHomeScreen loads and transitions through face detection and dispensing', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final settingsService = await SettingsService.init();
    final controller = KioskController(settingsService, enableBackgroundPurge: false);

    await tester.pumpWidget(
      ChangeNotifierProvider<KioskController>.value(
        value: controller,
        child: const MaterialApp(
          home: KioskHomeScreen(),
        ),
      ),
    );

    // Initial Idle State
    expect(find.text('SMART TOILET'), findsOneWidget);
    expect(find.text('VUI LÒNG NHÌN VÀO CAMERA'), findsOneWidget);

    // Trigger face detection directly via controller
    controller.triggerFaceDetected('person_01');
    await tester.pump();

    // Should transition to scanning state
    expect(find.text('ĐANG PHÂN TÍCH KHUÔN MẶT...'), findsOneWidget);

    // Advance animation past analyzing delay (600ms) and dispensing (40 steps x 30ms)
    await tester.pump(const Duration(milliseconds: 700));
    for (int i = 0; i < 45; i++) {
      await tester.pump(const Duration(milliseconds: 35));
    }

    // Should complete dispensing and reach success state
    expect(find.text('✓ ĐÃ CẤP GIẤY THÀNH CÔNG'), findsOneWidget);

    // Pump past the 4-second auto-reset timer to return to idle cleanly
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('VUI LÒNG NHÌN VÀO CAMERA'), findsOneWidget);
  });
}
