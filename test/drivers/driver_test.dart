import 'package:flutter_test/flutter_test.dart';
import 'package:smart_toilet_kiosk/drivers/mock_demo_driver.dart';

void main() {
  group('MockDemoDriver Tests', () {
    test('Dispenses smoothly and notifies progress callback', () async {
      final driver = MockDemoDriver(stepDuration: const Duration(milliseconds: 1));
      final progressUpdates = <double>[];
      final cmUpdates = <int>[];

      final success = await driver.dispense(
        lengthCm: 70,
        onProgress: (progress, currentCm) {
          progressUpdates.add(progress);
          cmUpdates.add(currentCm);
        },
      );

      expect(success, isTrue);
      expect(progressUpdates.isNotEmpty, isTrue);
      expect(progressUpdates.last, equals(1.0));
      expect(cmUpdates.last, equals(70));
    });

    test('Can be stopped/cancelled cleanly', () async {
      final driver = MockDemoDriver(stepDuration: const Duration(milliseconds: 50));
      
      final dispenseFuture = driver.dispense(
        lengthCm: 70,
        onProgress: (_, _) {},
      );

      await Future.delayed(const Duration(milliseconds: 30));
      await driver.stop();

      final result = await dispenseFuture;
      expect(result, isFalse);
    });
  });
}
