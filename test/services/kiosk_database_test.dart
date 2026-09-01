import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_toilet_kiosk/models/dispense_event.dart';
import 'package:smart_toilet_kiosk/models/face_profile.dart';
import 'package:smart_toilet_kiosk/models/kiosk_state.dart';
import 'package:smart_toilet_kiosk/services/kiosk_database_service.dart';

void main() {
  // Khởi tạo sqflite_common_ffi để chạy SQLite in-memory trong unit test
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late KioskDatabaseService dbService;
  late Database inMemoryDb;

  setUp(() async {
    inMemoryDb = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
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
            CREATE TABLE IF NOT EXISTS deletion_jobs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              target_table TEXT NOT NULL,
              target_id INTEGER NOT NULL,
              reason TEXT,
              scheduled_at INTEGER NOT NULL,
              executed_at INTEGER
            );
          ''');
        },
      ),
    );

    dbService = KioskDatabaseService();
    await dbService.init(overrideDb: inMemoryDb);
  });

  tearDown(() async {
    await dbService.close();
  });

  group('KioskDatabaseService Configuration Tests', () {
    test('Loads default config when table is empty and saves correctly', () async {
      final config = await dbService.loadConfig();
      expect(config.paperLengthCm, equals(70));
      expect(config.cooldownMinutes, equals(9));

      final updatedConfig = config.copyWith(
        paperLengthCm: 85,
        cooldownMinutes: 12,
        connectionMode: ConnectionMode.http,
      );
      await dbService.saveConfig(updatedConfig);

      final reloaded = await dbService.loadConfig();
      expect(reloaded.paperLengthCm, equals(85));
      expect(reloaded.cooldownMinutes, equals(12));
      expect(reloaded.connectionMode, equals(ConnectionMode.http));
    });
  });

  group('KioskDatabaseService Dispense & Stats Tests', () {
    test('Logs dispense event and atomically updates daily usage_stats', () async {
      final now = DateTime.now();
      final event1 = DispenseEvent(
        deviceId: 'kiosk_main',
        userFaceHash: 'hash_user_1',
        paperLengthCm: 70,
        isSuccess: true,
        connectionMode: 'demo',
        createdAt: now,
      );

      final event2 = DispenseEvent(
        deviceId: 'kiosk_main',
        userFaceHash: 'hash_user_2',
        paperLengthCm: 70,
        isSuccess: true,
        connectionMode: 'demo',
        createdAt: now.add(const Duration(seconds: 1)),
      );

      await dbService.logDispenseEvent(event1);
      await dbService.logDispenseEvent(event2);

      final events = await dbService.getRecentEvents(limit: 10);
      expect(events.length, equals(2));
      expect(events.first.userFaceHash, equals('hash_user_2'));

      final stats = await dbService.getSummaryStats();
      expect(stats['totalUsesToday'], equals(2));
      expect(stats['totalMetersToday'], equals('1.4')); // (70 + 70) / 100
      expect(stats['allTimeCount'], equals(2));
    });
  });

  group('KioskDatabaseService Cooldown & Privacy Purge Tests', () {
    test('Stores 192-d face vector and purges expired profiles', () async {
      final testEmbedding = List<double>.generate(192, (i) => i * 0.01);
      final validExpiry = DateTime.now().add(const Duration(minutes: 9));
      final expiredTime = DateTime.now().subtract(const Duration(minutes: 5));

      // 1. Lưu khuôn mặt còn hạn
      await dbService.saveActiveCooldownFace(
        faceHash: 'active_user_face',
        embedding: testEmbedding,
        expiry: validExpiry,
      );

      // 2. Lưu khuôn mặt đã hết hạn
      await dbService.saveActiveCooldownFace(
        faceHash: 'expired_user_face',
        embedding: testEmbedding,
        expiry: expiredTime,
      );

      // 3. Kiểm tra loadActiveCooldownProfiles chỉ nạp mặt còn hạn
      final activeProfiles = await dbService.loadActiveCooldownProfiles();
      final hasActive = activeProfiles.any((p) => p.faceHash == 'active_user_face');
      final hasExpired = activeProfiles.any((p) => p.faceHash == 'expired_user_face');
      expect(hasActive, isTrue);
      expect(hasExpired, isFalse);
      expect(activeProfiles.firstWhere((p) => p.faceHash == 'active_user_face').embedding192d?.length, equals(192));

      // 4. Chạy Privacy Purge
      final purged = await dbService.purgeExpiredData();
      expect(purged, equals(1)); // Đã xóa expired_user_face khỏi database
    });

    test('FaceProfile BLOB serialization preserves exact float precision', () {
      final original = [0.123456, -0.789012, 1.0, 0.0];
      final blob = FaceProfile.embeddingToBlob(original);
      expect(blob, isNotNull);

      final restored = FaceProfile.blobToEmbedding(blob);
      expect(restored, isNotNull);
      expect(restored!.length, equals(4));
      expect(restored[0], closeTo(0.123456, 0.0001));
      expect(restored[1], closeTo(-0.789012, 0.0001));
      expect(restored[2], closeTo(1.0, 0.0001));
      expect(restored[3], closeTo(0.0, 0.0001));
    });
  });
}
