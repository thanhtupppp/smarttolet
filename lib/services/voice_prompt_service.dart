import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum VoicePromptType {
  welcome,
  dispensing,
  cooldown,
  paperEmpty,
  error,
}

/// Service phát giọng nói tiếng Việt tự động hướng dẫn người dùng Kiosk qua loa thiết bị
class VoicePromptService {
  static final VoicePromptService _instance = VoicePromptService._internal();
  factory VoicePromptService() => _instance;

  FlutterTts? _flutterTts;
  bool _isTtsInitialized = false;
  bool isMuted = false;
  VoicePromptType? lastPrompt;

  VoicePromptService._internal() {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        _flutterTts = FlutterTts();
        await _flutterTts!.setLanguage("vi-VN");
        await _flutterTts!.setSpeechRate(0.48); // Tốc độ nói vừa phải, rõ ràng
        await _flutterTts!.setVolume(1.0);     // Âm lượng tối đa
        await _flutterTts!.setPitch(1.0);
        _isTtsInitialized = true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[VoicePrompt TTS] Initialization note: $e');
      }
    }
  }

  /// Phát thông báo giọng nói tiếng Việt theo loại sự kiện
  Future<void> playPrompt(
    VoicePromptType type, {
    int? remainingMinutes,
    int? paperLengthCm,
  }) async {
    if (isMuted) return;
    lastPrompt = type;

    String message = '';
    switch (type) {
      case VoicePromptType.welcome:
        message = 'Xin chào, vui lòng nhìn vào camera để nhận giấy.';
        break;
      case VoicePromptType.dispensing:
        final cm = paperLengthCm ?? 70;
        message = 'Đang cấp $cm xăng-ti-mét giấy, vui lòng nhận giấy phía dưới.';
        break;
      case VoicePromptType.cooldown:
        final mins = (remainingMinutes != null && remainingMinutes > 0) ? remainingMinutes : 9;
        message = 'Bạn vừa nhận giấy, vui lòng đợi thêm $mins phút để nhận tiếp.';
        break;
      case VoicePromptType.paperEmpty:
        message = 'Thiết bị tạm hết giấy, vui lòng liên hệ nhân viên.';
        break;
      case VoicePromptType.error:
        message = 'Thiết bị gặp sự cố, xin vui lòng thử lại sau.';
        break;
    }

    if (kDebugMode) {
      print('[VoicePrompt TTS Speaker] 🔊 "$message"');
    }

    try {
      if (_flutterTts != null && _isTtsInitialized) {
        await _flutterTts!.stop();
        await _flutterTts!.speak(message);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[VoicePrompt TTS] Speak error: $e');
      }
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts?.stop();
    } catch (_) {}
  }

  void toggleMute() {
    isMuted = !isMuted;
    if (isMuted) {
      stop();
    }
  }
}
