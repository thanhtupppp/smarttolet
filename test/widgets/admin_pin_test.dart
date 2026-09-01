import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_toilet_kiosk/widgets/admin_pin_dialog.dart';
import 'package:smart_toilet_kiosk/widgets/hidden_trigger_button.dart';

void main() {
  testWidgets('AdminPinDialog accepts correct PIN and triggers onSuccess', (tester) async {
    bool unlocked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 450,
              height: 700,
              child: AdminPinDialog(
                expectedPin: '1234',
                onSuccess: () {
                  unlocked = true;
                },
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('XÁC THỰC ADMIN'), findsOneWidget);

    // Tap 1, 2, 3, 4
    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();

    expect(unlocked, isTrue);
  });

  testWidgets('AdminPinDialog shows error on wrong PIN', (tester) async {
    bool unlocked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 450,
              height: 700,
              child: AdminPinDialog(
                expectedPin: '1234',
                onSuccess: () {
                  unlocked = true;
                },
              ),
            ),
          ),
        ),
      ),
    );

    // Tap 9, 9, 9, 9
    await tester.tap(find.text('9'));
    await tester.pump();
    await tester.tap(find.text('9'));
    await tester.pump();
    await tester.tap(find.text('9'));
    await tester.pump();
    await tester.tap(find.text('9'));
    await tester.pump();

    expect(unlocked, isFalse);
    expect(find.textContaining('Mật khẩu không đúng!'), findsOneWidget);
  });

  testWidgets('HiddenTriggerButton triggers after full duration hold', (tester) async {
    bool triggered = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: HiddenTriggerButton(
              holdDuration: const Duration(milliseconds: 100),
              onTriggered: () {
                triggered = true;
              },
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(find.byType(HiddenTriggerButton)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await gesture.up();
    await tester.pump();

    expect(triggered, isTrue);
  });
}
