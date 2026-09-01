import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/dispenser_config.dart';
import '../models/dispense_record.dart';
import '../models/kiosk_state.dart';
import '../services/settings_service.dart';
import '../services/face_embedding_service.dart';
import '../services/voice_prompt_service.dart';
import '../drivers/dispenser_driver.dart';
import '../drivers/mock_demo_driver.dart';
import '../drivers/http_rest_driver.dart';
import '../drivers/websocket_driver.dart';

class KioskController extends ChangeNotifier {
  final SettingsService _settingsService;
  late DispenserConfig _config;
  DispenserDriver? _driver;
  final VoicePromptService _voicePrompt = VoicePromptService();

  KioskStatus _status = KioskStatus.idle;
  double _dispenseProgress = 0.0;
  int _currentDispensedCm = 0;
  String? _errorMessage;
  
  // Privacy-First Cooldown Tracking: faceId -> expiry DateTime
  final Map<String, DateTime> _cooldownMap = {};
  // In-memory 192-d Face Embeddings (auto-purged when cooldown expires)
  final Map<String, List<double>> _activeEmbeddings = {};

  Duration _activeCooldownRemaining = Duration.zero;
  Timer? _cooldownTicker;
  Timer? _resetTimer;
  Timer? _privacyPurgeTimer;
  String? _activeFaceId;

  KioskController(
    this._settingsService, {
    bool enableBackgroundPurge = true,
  }) {
    _config = _settingsService.loadConfig();
    _initDriver();
    _restoreCooldownProfilesFromDb();
    if (enableBackgroundPurge) {
      _startPeriodicPrivacyPurge();
    }
  }

  Future<void> _restoreCooldownProfilesFromDb() async {
    try {
      final profiles = await _settingsService.databaseService.loadActiveCooldownProfiles();
      for (final profile in profiles) {
        if (profile.embedding192d != null) {
          _activeEmbeddings[profile.faceHash] = profile.embedding192d!;
          if (profile.expiresAt != null) {
            _cooldownMap[profile.faceHash] = profile.expiresAt!;
          }
        }
      }
    } catch (_) {}
  }

  void _startPeriodicPrivacyPurge() {
    _privacyPurgeTimer?.cancel();
    // Chạy dọn dẹp mỗi 10 phút để tự động xóa sạch dữ liệu khuôn mặt và log quá hạn
    _privacyPurgeTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _settingsService.databaseService.purgeExpiredData().catchError((_) => 0);
    });
  }

  // Getters
  KioskStatus get status => _status;
  DispenserConfig get config => _config;
  DispenserDriver get driver => _driver!;
  double get dispenseProgress => _dispenseProgress;
  int get currentDispensedCm => _currentDispensedCm;
  String? get errorMessage => _errorMessage;
  Duration get activeCooldownRemaining => _activeCooldownRemaining;
  String? get activeFaceId => _activeFaceId;

  void _initDriver() {
    _driver?.dispose();
    switch (_config.connectionMode) {
      case ConnectionMode.demo:
        _driver = MockDemoDriver();
        break;
      case ConnectionMode.http:
        _driver = HttpRestDriver(baseUrl: 'http://${_config.espIp}:${_config.espPort}');
        break;
      case ConnectionMode.websocket:
        _driver = WebSocketDriver(wsUrl: _config.espWsUrl);
        break;
      case ConnectionMode.mqtt:
        _driver = MockDemoDriver();
        break;
    }
  }

  Future<void> updateConfig(DispenserConfig newConfig) async {
    _config = newConfig;
    await _settingsService.saveConfig(newConfig);
    _initDriver();
    notifyListeners();
  }

  // Check if a face is currently under cooldown
  bool isUnderCooldown(String faceId) {
    _purgeExpiredCooldowns();
    final expiry = _cooldownMap[faceId];
    if (expiry == null) return false;
    return DateTime.now().isBefore(expiry);
  }

  Duration getCooldownRemaining(String faceId) {
    _purgeExpiredCooldowns();
    final expiry = _cooldownMap[faceId];
    if (expiry == null) return Duration.zero;
    final diff = expiry.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Purges expired cooldown records and their vector embeddings from RAM (Privacy Guarantee)
  void _purgeExpiredCooldowns() {
    final now = DateTime.now();
    final expiredIds = <String>[];
    _cooldownMap.forEach((id, expiry) {
      if (now.isAfter(expiry)) {
        expiredIds.add(id);
      }
    });

    for (final id in expiredIds) {
      _cooldownMap.remove(id);
      _activeEmbeddings.remove(id);
    }
  }

  // --- DEBUG & TELEMETRY GETTERS ---
  String? _debugLastScannedFaceId;
  int? _debugLastTrackingId;
  double? _debugLastSimilarity;
  String? _debugMatchedCooldownFaceId;
  String? _debugVerdict;
  double? _debugLeftEye;
  double? _debugRightEye;

  String? get debugLastScannedFaceId => _debugLastScannedFaceId;
  int? get debugLastTrackingId => _debugLastTrackingId;
  double? get debugLastSimilarity => _debugLastSimilarity;
  String? get debugMatchedCooldownFaceId => _debugMatchedCooldownFaceId;
  String? get debugVerdict => _debugVerdict;
  double? get debugLeftEye => _debugLeftEye;
  double? get debugRightEye => _debugRightEye;

  void updateLiveTrackingDebug({
    required int? trackingId,
    required double? leftEye,
    required double? rightEye,
    required String seed,
  }) {
    _debugLastTrackingId = trackingId;
    _debugLeftEye = leftEye;
    _debugRightEye = rightEye;
    _debugLastScannedFaceId = seed;
    notifyListeners();
  }

  int? _lastDispensedTrackingId;
  DateTime? _lastDispenseFinishedAt;

  /// Triggered when face is detected in Camera Viewfinder
  Future<void> triggerFaceDetected(
    String faceId, {
    List<double>? embedding192d,
    int? trackingId,
    double boundingBoxRatio = 1.3,
    double eyeDistanceRatio = 0.45,
    double mouthWidthRatio = 0.9,
    double noseToMouthRatio = 0.25,
    double eyeToNoseRatio = 0.35,
    double cheekWidthRatio = 0.85,
    double faceSymmetryRatio = 1.0,
  }) async {
    if (_status != KioskStatus.idle) return;

    // Khóa chống gian lận 1: Nếu cùng 1 người vẫn đứng trước camera (trùng tracking ID của ML Kit)
    if (trackingId != null && trackingId == _lastDispensedTrackingId) {
      _debugLastScannedFaceId = faceId;
      _debugLastTrackingId = trackingId;
      _debugVerdict = 'TRÙNG TRACK ID #$trackingId (CÙNG NGƯỜI ĐỨNG) -> CHẶN';
      notifyListeners();

      final remainingMins = (getCooldownRemaining(faceId).inSeconds / 60).ceil();
      _voicePrompt.playPrompt(
        VoicePromptType.cooldown,
        remainingMinutes: remainingMins > 0 ? remainingMins : _config.cooldownMinutes,
      );
      _startCooldownView(faceId);
      return;
    }

    // Khóa chống gian lận 2: Không cấp liên tiếp nếu vừa hoàn thành cấp giấy chưa đầy 5 giây
    if (_lastDispenseFinishedAt != null &&
        DateTime.now().difference(_lastDispenseFinishedAt!) < const Duration(seconds: 5)) {
      return;
    }

    _purgeExpiredCooldowns();
    _activeFaceId = faceId;
    _status = KioskStatus.scanning;
    _errorMessage = null;
    notifyListeners();

    // 1. Sử dụng vector từ Deep Learning MobileFaceNet (nếu có), hoặc fallback về pseudo-embedding
    final queryEmbedding = embedding192d ?? FaceEmbeddingService.extractEmbedding(
      boundingBoxRatio: boundingBoxRatio,
      eyeDistanceRatio: eyeDistanceRatio,
      mouthWidthRatio: mouthWidthRatio,
      noseToMouthRatio: noseToMouthRatio,
      eyeToNoseRatio: eyeToNoseRatio,
      cheekWidthRatio: cheekWidthRatio,
      faceSymmetryRatio: faceSymmetryRatio,
      rawFeaturesSeed: faceId,
    );

    // 2. So khớp Cosine Similarity với danh sách khuôn mặt đang trong Cooldown
    final matchResult = FaceEmbeddingService.evaluateMatch(
      queryEmbedding: queryEmbedding,
      activeEmbeddings: _activeEmbeddings,
    );

    _debugLastScannedFaceId = faceId;
    _debugLastTrackingId = trackingId;
    _debugLastSimilarity = matchResult.highestSimilarity;
    _debugMatchedCooldownFaceId = matchResult.matchedId ?? matchResult.closestFaceId;

    // UX delay for scanning animation
    await Future.delayed(const Duration(milliseconds: 600));

    if (matchResult.isMatch || isUnderCooldown(faceId)) {
      final effectiveId = matchResult.matchedId ?? faceId;
      final simPercent = (matchResult.highestSimilarity * 100).toStringAsFixed(1);
      _debugVerdict = 'TRÙNG ID: $effectiveId (Sim: $simPercent% >= 75%) -> COOLDOWN';
      notifyListeners();

      final remainingMins = (getCooldownRemaining(effectiveId).inSeconds / 60).ceil();
      _voicePrompt.playPrompt(
        VoicePromptType.cooldown,
        remainingMinutes: remainingMins > 0 ? remainingMins : _config.cooldownMinutes,
      );
      _startCooldownView(effectiveId);
      return;
    }

    // 3. Người mới: Lưu vector nhúng & mốc Cooldown duy nhất 1 lần
    final expiry = DateTime.now().add(Duration(minutes: _config.cooldownMinutes));
    _cooldownMap[faceId] = expiry;
    _activeEmbeddings[faceId] = queryEmbedding;
    _lastDispensedTrackingId = trackingId;

    final maxSimText = matchResult.highestSimilarity > 0
        ? ' (Max Sim: ${(matchResult.highestSimilarity * 100).toStringAsFixed(1)}% < 75%)'
        : '';
    _debugVerdict = 'KHÁCH MỚI$maxSimText -> CẤP GIẤY';
    notifyListeners();

    // Lưu bền vững vào SQLite để chống gian lận khi tắt mở lại Kiosk
    _settingsService.databaseService.saveActiveCooldownFace(
      faceHash: faceId,
      embedding: queryEmbedding,
      expiry: expiry,
      note: 'Auto Cooldown',
    ).catchError((_) {});

    _voicePrompt.playPrompt(
      VoicePromptType.dispensing,
      paperLengthCm: _config.paperLengthCm,
    );
    await _dispensePaper(faceId);
  }

  void _startCooldownView(String faceId) {
    _status = KioskStatus.cooldown;
    _activeCooldownRemaining = getCooldownRemaining(faceId);
    notifyListeners();

    _cooldownTicker?.cancel();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = getCooldownRemaining(faceId);
      if (remaining == Duration.zero) {
        timer.cancel();
        resetToIdle();
      } else {
        _activeCooldownRemaining = remaining;
        notifyListeners();
      }
    });

    // Auto-return to idle after 6 seconds if user walks away
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 6), () {
      resetToIdle();
    });
  }

  Future<void> _dispensePaper(String faceId) async {
    _status = KioskStatus.dispensing;
    _dispenseProgress = 0.0;
    _currentDispensedCm = 0;
    notifyListeners();

    final targetCm = _config.paperLengthCm;
    
    final success = await _driver!.dispense(
      lengthCm: targetCm,
      onProgress: (progress, currentCm) {
        _dispenseProgress = progress;
        _currentDispensedCm = currentCm;
        notifyListeners();
      },
    );

    if (success) {
      _status = KioskStatus.success;

      // Update paper used in config
      final addedMeters = targetCm / 100.0;
      _config = _config.copyWith(
        paperUsedMeters: _config.paperUsedMeters + addedMeters,
      );
      await _settingsService.saveConfig(_config);

      // Record to history
      await _settingsService.addRecord(
        DispenseRecord(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.now(),
          lengthCm: targetCm,
          isSuccess: true,
          mode: _config.connectionMode.name,
        ),
      );

      notifyListeners();

      // Return to idle after 4 seconds
      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(seconds: 4), () {
        _lastDispenseFinishedAt = DateTime.now();
        resetToIdle();
      });
    } else {
      _status = KioskStatus.error;
      _errorMessage = 'Không thể cấp giấy. Vui lòng kiểm tra thiết bị!';
      _voicePrompt.playPrompt(VoicePromptType.error);
      
      await _settingsService.addRecord(
        DispenseRecord(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.now(),
          lengthCm: targetCm,
          isSuccess: false,
          mode: _config.connectionMode.name,
          errorMessage: _errorMessage,
        ),
      );

      notifyListeners();

      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(seconds: 5), () {
        resetToIdle();
      });
    }
  }

  void resetToIdle() {
    _cooldownTicker?.cancel();
    _resetTimer?.cancel();
    _status = KioskStatus.idle;
    _dispenseProgress = 0.0;
    _currentDispensedCm = 0;
    _activeFaceId = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> resetPaperRoll() async {
    _config = _config.copyWith(paperUsedMeters: 0.0);
    await _settingsService.saveConfig(_config);
    notifyListeners();
  }

  @override
  void dispose() {
    _privacyPurgeTimer?.cancel();
    _cooldownTicker?.cancel();
    _resetTimer?.cancel();
    _driver?.dispose();
    super.dispose();
  }
}
