import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_toilet_kiosk/controllers/kiosk_controller.dart';
import 'package:smart_toilet_kiosk/screens/admin_settings_screen.dart';
import 'package:smart_toilet_kiosk/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AdminSettingsScreen renders configuration controls and stats', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    final settingsService = await SettingsService.init();
    final controller = KioskController(settingsService, enableBackgroundPurge: false);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<KioskController>.value(
        value: controller,
        child: const MaterialApp(
          home: AdminSettingsScreen(),
        ),
      ),
    );

    expect(find.text('BẢNG ĐIỀU KHIỂN ADMIN'), findsOneWidget);
    expect(find.text('1. CẤU HÌNH CẤP GIẤY'), findsOneWidget);
    expect(find.text('2. GIAO TIẾP VỚI ESP32'), findsOneWidget);
    expect(find.text('3. HIỆU CHUẨN MOTOR & ENCODER'), findsOneWidget);
    expect(find.text('4. BẢO MẬT & MÃ PIN ADMIN'), findsOneWidget);
    expect(find.text('LƯU CẤU HÌNH KIOSK'), findsOneWidget);
  });
}
