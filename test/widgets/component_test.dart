import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_toilet_kiosk/widgets/camera_mock_view.dart';
import 'package:smart_toilet_kiosk/widgets/paper_dispense_animation.dart';
import 'package:smart_toilet_kiosk/widgets/cooldown_timer_view.dart';

void main() {
  testWidgets('CameraMockView renders viewfinder overlay correctly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: CameraMockView(isFaceDetected: false),
          ),
        ),
      ),
    );

    expect(find.text('CAMERA HOẠT ĐỘNG'), findsOneWidget);
    expect(find.text('VUI LÒNG NHÌN VÀO CAMERA'), findsOneWidget);
  });

  testWidgets('PaperDispenseAnimation displays current and target cm', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PaperDispenseAnimation(
            progress: 0.5,
            currentCm: 35,
            targetCm: 70,
          ),
        ),
      ),
    );

    expect(find.text('35'), findsOneWidget);
    expect(find.text('/ 70 cm'), findsOneWidget);
    expect(find.text('Tiến độ: 50%'), findsOneWidget);
  });

  testWidgets('CooldownTimerView displays remaining duration properly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CooldownTimerView(
            remaining: Duration(minutes: 5, seconds: 30),
            totalCooldownMinutes: 9,
          ),
        ),
      ),
    );

    expect(find.text('05:30'), findsOneWidget);
    expect(find.text('THỜI GIAN CHỜ (COOLDOWN)'), findsOneWidget);
  });
}
