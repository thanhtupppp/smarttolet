import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/dispenser_config.dart';
import '../models/dispense_event.dart';
import '../models/face_profile.dart';
import '../models/kiosk_state.dart';

/// Dịch vụ quản trị Cơ sở dữ liệu SQLite cục bộ (Offline-First Kiosk Database)
/// Tuân thủ nguyên tắc Privacy-by-Design & ACID Transactions
class KioskDatabaseService {
  static const String databaseName = 'smart_toilet_kiosk.db';
  static const int databaseVersion = 1;

  Database? _db;

  Database get database {
    if (_db == null) {
      throw StateError('KioskDatabaseService chưa được khởi tạo. Hãy gọi init() trước.');
    }
    return _db!;
  }

  /// Khởi tạo và mở Database SQLite (có thể truyền overrideDb khi chạy Unit Test)
  Future<void> init({Database? overrideDb}) async {
    if (overrideDb != null) {
      _db = overrideDb;
      return;
    }

    if (_db != null && _db!.isOpen) return;

    // Tự động dùng In-Memory Database khi chạy trong môi trường Unit Test
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: databaseVersion,
          onCreate: _onCreate,
        ),
      );
      return;
    }

    // Kích hoạt FFI database factory trên Desktop (Windows / Linux)
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    try {
      final dbDir = await getDatabasesPath();
      final dbPath = p.join(dbDir, databaseName);

      _db = await openDatabase(
        dbPath,
        version: databaseVersion,
        onConfigure: (db) async {
          // Kích hoạt WAL mode để tối ưu hiệu năng ghi đồng thời và chống hỏng dữ liệu khi mất điện
          await db.execute('PRAGMA journal_mode = WAL;');
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: _onCreate,
      );
    } catch (_) {
      // Fallback an toàn khi chạy trong môi trường test thiếu native plugin
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: databaseVersion,
          onCreate: _onCreate,
        ),
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Bảng cấu hình Kiosk (Single-row)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kiosk_config (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        device_id TEXT NOT NULL,
        paper_length_cm INTEGER NOT NULL DEFAULT 70,
        cooldown_minutes INTEGER NOT NULL DEFAULT 9,
        cosine_threshold REAL NOT NULL DEFAULT 0.75,
        connection_mode TEXT NOT NULL DEFAULT 'demo',
        esp_ip TEXT NOT NULL DEFAULT '192.168.4.1',
        esp_port INTEGER NOT NULL DEFAULT 80,
        esp_ws_url TEXT NOT NULL DEFAULT 'ws://192.168.4.1/ws',
        pulse_per_cm INTEGER NOT NULL DEFAULT 10,
        admin_pin TEXT NOT NULL DEFAULT '1234',
        total_roll_capacity_meters INTEGER NOT NULL DEFAULT 100,
        paper_used_meters REAL NOT NULL DEFAULT 0.0,
        updated_at INTEGER NOT NULL
      );
    ''');

    // 2. Bảng lịch sử cấp giấy (Dispense Events)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dispense_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT NOT NULL,
        user_face_hash TEXT,
        paper_length_cm INTEGER NOT NULL,
        match_score REAL,
        liveness_passed INTEGER DEFAULT 1,
        is_success INTEGER NOT NULL DEFAULT 1,
        error_message TEXT,
        connection_mode TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_dispense_events_created_at 
      ON dispense_events(created_at);
    ''');

    // 3. Bảng thống kê sử dụng theo ngày (Usage Stats)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS usage_stats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT NOT NULL,
        date TEXT NOT NULL,
        total_events INTEGER NOT NULL DEFAULT 0,
        total_paper_cm INTEGER NOT NULL DEFAULT 0,
        success_count INTEGER NOT NULL DEFAULT 0,
        fail_count INTEGER NOT NULL DEFAULT 0,
        UNIQUE(device_id, date)
      );
    ''');

    // 4. Bảng hồ sơ khuôn mặt Cooldown / Whitelist (Face Profiles)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS face_profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        face_hash TEXT NOT NULL UNIQUE,
        embedding_blob BLOB,
        note TEXT,
        created_at INTEGER NOT NULL,
        expires_at INTEGER
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_face_profiles_expires 
      ON face_profiles(expires_at);
    ''');

    // 5. Bảng ghi nhận lịch trình xóa theo chính sách riêng tư (Deletion Jobs)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS deletion_jobs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        target_table TEXT NOT NULL,
        target_id INTEGER NOT NULL,
        reason TEXT,
        scheduled_at INTEGER NOT NULL,
        executed_at INTEGER
      );
    ''');
  }

  // ==========================================
  // QUẢN LÝ CẤU HÌNH KIOSK (kiosk_config)
  // ==========================================

  Future<DispenserConfig> loadConfig({String deviceId = 'kiosk_main'}) async {
    final rows = await database.query(
      'kiosk_config',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (rows.isEmpty) {
      const defaultConfig = DispenserConfig();
      await saveConfig(defaultConfig, deviceId: deviceId);
      return defaultConfig;
    }

    final row = rows.first;
    final connModeStr = row['connection_mode'] as String? ?? 'demo';
    final connMode = ConnectionMode.values.firstWhere(
      (m) => m.name == connModeStr,
      orElse: () => ConnectionMode.demo,
    );

    return DispenserConfig(
      paperLengthCm: (row['paper_length_cm'] as num?)?.toInt() ?? 70,
      cooldownMinutes: (row['cooldown_minutes'] as num?)?.toInt() ?? 9,
      connectionMode: connMode,
      espIp: row['esp_ip'] as String? ?? '192.168.4.1',
      espPort: (row['esp_port'] as num?)?.toInt() ?? 80,
      espWsUrl: row['esp_ws_url'] as String? ?? 'ws://192.168.4.1/ws',
      pulsePerCm: (row['pulse_per_cm'] as num?)?.toInt() ?? 10,
      adminPin: row['admin_pin'] as String? ?? '1234',
      totalRollCapacityMeters: (row['total_roll_capacity_meters'] as num?)?.toInt() ?? 100,
      paperUsedMeters: (row['paper_used_meters'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Future<void> saveConfig(
    DispenserConfig config, {
    String deviceId = 'kiosk_main',
  }) async {
    await database.insert(
      'kiosk_config',
      {
        'id': 1,
        'device_id': deviceId,
        'paper_length_cm': config.paperLengthCm,
        'cooldown_minutes': config.cooldownMinutes,
        'cosine_threshold': 0.75,
        'connection_mode': config.connectionMode.name,
        'esp_ip': config.espIp,
        'esp_port': config.espPort,
        'esp_ws_url': config.espWsUrl,
        'pulse_per_cm': config.pulsePerCm,
        'admin_pin': config.adminPin,
        'total_roll_capacity_meters': config.totalRollCapacityMeters,
        'paper_used_meters': config.paperUsedMeters,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ==========================================
  // GHI LOG & THỐNG KÊ (dispense_events & usage_stats)
  // ==========================================

  /// Ghi nhận một sự kiện cấp giấy và cập nhật ngay vào bảng usage_stats trong 1 Transaction
  Future<int> logDispenseEvent(DispenseEvent event) async {
    return await database.transaction<int>((txn) async {
      // 1. Thêm vào bảng dispense_events
      final eventId = await txn.insert('dispense_events', event.toMap());

      // 2. Định dạng ngày YYYY-MM-DD
      final d = event.createdAt;
      final dateStr = '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

      // 3. Upsert vào bảng usage_stats
      await txn.rawInsert('''
        INSERT INTO usage_stats (
          device_id, date, total_events, total_paper_cm, success_count, fail_count
        ) VALUES (?, ?, 1, ?, ?, ?)
        ON CONFLICT(device_id, date) DO UPDATE SET
          total_events = total_events + 1,
          total_paper_cm = total_paper_cm + excluded.total_paper_cm,
          success_count = success_count + excluded.success_count,
          fail_count = fail_count + excluded.fail_count;
      ''', [
        event.deviceId,
        dateStr,
        event.isSuccess ? event.paperLengthCm : 0,
        event.isSuccess ? 1 : 0,
        event.isSuccess ? 0 : 1,
      ]);

      return eventId;
    });
  }

  /// Lấy danh sách sự kiện cấp giấy gần nhất
  Future<List<DispenseEvent>> getRecentEvents({int limit = 50}) async {
    final rows = await database.query(
      'dispense_events',
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
    );
    return rows.map((r) => DispenseEvent.fromMap(r)).toList();
  }

  /// Thống kê nhanh tổng quan phục vụ giao diện Dashboard / Admin
  Future<Map<String, dynamic>> getSummaryStats({String deviceId = 'kiosk_main'}) async {
    final now = DateTime.now();
    final todayStr = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    // Thống kê hôm nay từ usage_stats
    final todayStats = await database.query(
      'usage_stats',
      where: 'device_id = ? AND date = ?',
      whereArgs: [deviceId, todayStr],
      limit: 1,
    );

    int totalUsesToday = 0;
    int totalCmToday = 0;

    if (todayStats.isNotEmpty) {
      totalUsesToday = (todayStats.first['success_count'] as num?)?.toInt() ?? 0;
      totalCmToday = (todayStats.first['total_paper_cm'] as num?)?.toInt() ?? 0;
    }

    // Tổng số lượt thành công toàn thời gian
    final countResult = await database.rawQuery(
      'SELECT COUNT(*) as cnt FROM dispense_events WHERE is_success = 1'
    );
    final allTimeCount = Sqflite.firstIntValue(countResult) ?? 0;

    return {
      'totalUsesToday': totalUsesToday,
      'totalMetersToday': (totalCmToday / 100.0).toStringAsFixed(1),
      'allTimeCount': allTimeCount,
    };
  }

  // ==========================================
  // QUẢN LÝ COOLDOWN KHUÔN MẶT (face_profiles)
  // ==========================================

  /// Lưu khuôn mặt đang trong thời gian Cooldown
  Future<void> saveActiveCooldownFace({
    required String faceHash,
    required List<double> embedding,
    required DateTime expiry,
    String? note,
  }) async {
    final profile = FaceProfile(
      faceHash: faceHash,
      embedding192d: embedding,
      note: note,
      createdAt: DateTime.now(),
      expiresAt: expiry,
    );

    await database.insert(
      'face_profiles',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Đọc các khuôn mặt đang trong thời gian Cooldown còn hiệu lực (bao gồm cả hạn expiresAt)
  Future<List<FaceProfile>> loadActiveCooldownProfiles() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final rows = await database.query(
      'face_profiles',
      where: 'expires_at IS NULL OR expires_at > ?',
      whereArgs: [nowMs],
    );

    return rows.map((row) => FaceProfile.fromMap(row)).toList();
  }

  // ==========================================
  // CHÍNH SÁCH QUYỀN RIÊNG TƯ (Privacy Purge)
  // ==========================================

  /// Tự động dọn dẹp các khuôn mặt đã hết hạn Cooldown và nhật ký cũ theo chính sách bảo mật
  Future<int> purgeExpiredData({
    Duration retainLogsDuration = const Duration(days: 30),
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    int deletedCount = 0;

    // 1. Xóa các profile khuôn mặt đã hết hạn
    deletedCount += await database.delete(
      'face_profiles',
      where: 'expires_at IS NOT NULL AND expires_at <= ?',
      whereArgs: [nowMs],
    );

    // 2. Xóa các log sự kiện quá 30 ngày (nếu cần bảo mật tối đa)
    final thresholdMs = nowMs - retainLogsDuration.inMilliseconds;
    final oldEventsCount = await database.delete(
      'dispense_events',
      where: 'created_at < ?',
      whereArgs: [thresholdMs],
    );

    if (kDebugMode) {
      print('[KioskDatabaseService] Purged $deletedCount expired face profiles, $oldEventsCount old logs.');
    }

    return deletedCount;
  }

  /// Đóng cơ sở dữ liệu khi ứng dụng tắt
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
