import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dispenser_config.dart';
import '../models/dispense_record.dart';
import '../models/dispense_event.dart';
import 'kiosk_database_service.dart';

class SettingsService {
  static const String _configKey = 'smart_toilet_config';
  static const String _recordsKey = 'smart_toilet_records';

  final SharedPreferences _prefs;
  final KioskDatabaseService databaseService;
  DispenserConfig _cachedConfig = const DispenserConfig();

  SettingsService(this._prefs, this.databaseService);

  KioskDatabaseService get db => databaseService;

  static Future<SettingsService> init({
    SharedPreferences? prefs,
    KioskDatabaseService? dbService,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final db = dbService ?? KioskDatabaseService();
    await db.init();
    final service = SettingsService(p, db);
    await service._migrateAndCache();
    return service;
  }

  /// Đồng bộ và di chuyển dữ liệu từ SharedPreferences sang SQLite nếu cần
  Future<void> _migrateAndCache() async {
    // 1. Nạp config từ SQLite
    var config = await databaseService.loadConfig();

    // Nếu SQLite chưa có cấu hình tùy biến nhưng SharedPreferences có, ưu tiên migrate
    final jsonString = _prefs.getString(_configKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final map = jsonDecode(jsonString) as Map<String, dynamic>;
        final legacyConfig = DispenserConfig.fromJson(map);
        if (legacyConfig.paperLengthCm != config.paperLengthCm ||
            legacyConfig.cooldownMinutes != config.cooldownMinutes ||
            legacyConfig.paperUsedMeters > config.paperUsedMeters) {
          config = legacyConfig;
          await databaseService.saveConfig(config);
        }
      } catch (_) {}
    }

    _cachedConfig = config;

    // 2. Migrate lịch sử cấp giấy nếu SQLite đang trống
    final existingEvents = await databaseService.getRecentEvents(limit: 1);
    if (existingEvents.isEmpty) {
      final legacyRecords = loadRecords();
      for (final r in legacyRecords.reversed) {
        final event = DispenseEvent(
          deviceId: 'kiosk_main',
          paperLengthCm: r.lengthCm,
          isSuccess: r.isSuccess,
          errorMessage: r.errorMessage,
          connectionMode: r.mode,
          createdAt: r.timestamp,
        );
        await databaseService.logDispenseEvent(event);
      }
    }
  }

  DispenserConfig loadConfig() {
    return _cachedConfig;
  }

  Future<bool> saveConfig(DispenserConfig config) async {
    _cachedConfig = config;
    try {
      await databaseService.saveConfig(config);
    } catch (_) {}
    
    // Lưu song song vào SharedPreferences để tương thích tối đa
    final jsonString = jsonEncode(config.toJson());
    return await _prefs.setString(_configKey, jsonString);
  }

  List<DispenseRecord> loadRecords() {
    final jsonList = _prefs.getStringList(_recordsKey);
    if (jsonList == null) return [];
    try {
      return jsonList
          .map((item) => DispenseRecord.fromJson(jsonDecode(item) as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (_) {
      return [];
    }
  }

  Future<bool> addRecord(DispenseRecord record) async {
    // Ghi vào SQLite Transaction
    try {
      final event = DispenseEvent(
        deviceId: 'kiosk_main',
        paperLengthCm: record.lengthCm,
        isSuccess: record.isSuccess,
        errorMessage: record.errorMessage,
        connectionMode: record.mode,
        createdAt: record.timestamp,
      );
      await databaseService.logDispenseEvent(event);
    } catch (_) {}

    // Ghi vào SharedPreferences
    final records = loadRecords();
    records.insert(0, record);
    final trimmed = records.take(100).toList();
    final jsonList = trimmed.map((r) => jsonEncode(r.toJson())).toList();
    return await _prefs.setStringList(_recordsKey, jsonList);
  }

  Future<bool> clearRecords() async {
    return await _prefs.remove(_recordsKey);
  }

  // Summary statistics
  Map<String, dynamic> getStats() {
    final records = loadRecords();
    final now = DateTime.now();
    final todayRecords = records.where((r) =>
        r.timestamp.year == now.year &&
        r.timestamp.month == now.month &&
        r.timestamp.day == now.day &&
        r.isSuccess).toList();

    final totalCmToday = todayRecords.fold<int>(0, (sum, r) => sum + r.lengthCm);
    final totalUsesToday = todayRecords.length;

    return {
      'totalUsesToday': totalUsesToday,
      'totalMetersToday': (totalCmToday / 100).toStringAsFixed(1),
      'allTimeCount': records.where((r) => r.isSuccess).length,
    };
  }

  Future<Map<String, dynamic>> getSqliteStats() async {
    return await databaseService.getSummaryStats();
  }
}
