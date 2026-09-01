import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dispenser_config.dart';
import '../models/dispense_record.dart';

class SettingsService {
  static const String _configKey = 'smart_toilet_config';
  static const String _recordsKey = 'smart_toilet_records';

  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  static Future<SettingsService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService(prefs);
  }

  DispenserConfig loadConfig() {
    final jsonString = _prefs.getString(_configKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final map = jsonDecode(jsonString) as Map<String, dynamic>;
        return DispenserConfig.fromJson(map);
      } catch (_) {
        return const DispenserConfig();
      }
    }
    return const DispenserConfig();
  }

  Future<bool> saveConfig(DispenserConfig config) async {
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
    final records = loadRecords();
    records.insert(0, record);
    // Keep max 100 recent records
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
}
