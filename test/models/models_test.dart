import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_toilet_kiosk/models/dispenser_config.dart';
import 'package:smart_toilet_kiosk/models/dispense_record.dart';
import 'package:smart_toilet_kiosk/models/kiosk_state.dart';
import 'package:smart_toilet_kiosk/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DispenserConfig Tests', () {
    test('Default config values are standard', () {
      const config = DispenserConfig();
      expect(config.paperLengthCm, equals(70));
      expect(config.cooldownMinutes, equals(9));
      expect(config.connectionMode, equals(ConnectionMode.demo));
      expect(config.espIp, equals('192.168.4.1'));
      expect(config.adminPin, equals('1234'));
      expect(config.remainingPercentage, equals(100.0));
    });

    test('toJson and fromJson serialize properly', () {
      const config = DispenserConfig(
        paperLengthCm: 85,
        cooldownMinutes: 15,
        connectionMode: ConnectionMode.websocket,
        espIp: '192.168.1.100',
        adminPin: '9999',
        totalRollCapacityMeters: 50,
        paperUsedMeters: 10,
      );

      final json = config.toJson();
      final restored = DispenserConfig.fromJson(json);

      expect(restored.paperLengthCm, equals(85));
      expect(restored.cooldownMinutes, equals(15));
      expect(restored.connectionMode, equals(ConnectionMode.websocket));
      expect(restored.espIp, equals('192.168.1.100'));
      expect(restored.adminPin, equals('9999'));
      expect(restored.remainingPercentage, equals(80.0));
    });
  });

  group('SettingsService Tests', () {
    test('Saves and loads config with SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final service = await SettingsService.init();

      final initial = service.loadConfig();
      expect(initial.paperLengthCm, equals(70));

      final updated = initial.copyWith(paperLengthCm: 90, cooldownMinutes: 5);
      await service.saveConfig(updated);

      final reloaded = service.loadConfig();
      expect(reloaded.paperLengthCm, equals(90));
      expect(reloaded.cooldownMinutes, equals(5));
    });

    test('Manages dispense records and stats correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final service = await SettingsService.init();

      final record = DispenseRecord(
        id: 'rec-1',
        timestamp: DateTime.now(),
        lengthCm: 70,
        isSuccess: true,
        mode: 'demo',
      );

      await service.addRecord(record);
      final records = service.loadRecords();
      expect(records.length, equals(1));
      expect(records.first.lengthCm, equals(70));

      final stats = service.getStats();
      expect(stats['totalUsesToday'], equals(1));
      expect(stats['totalMetersToday'], equals('0.7'));
    });
  });
}
