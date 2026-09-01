import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dispenser_driver.dart';

class WebSocketDriver implements DispenserDriver {
  final String wsUrl;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  WebSocketDriver({required this.wsUrl});

  @override
  String get name => 'WebSocket Stream ($wsUrl)';

  @override
  Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse(wsUrl);
      final channel = WebSocketChannel.connect(uri);
      await channel.ready.timeout(const Duration(seconds: 3));
      channel.sink.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> dispense({
    required int lengthCm,
    required ProgressCallback onProgress,
  }) async {
    final completer = Completer<bool>();
    try {
      final uri = Uri.parse(wsUrl);
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready.timeout(const Duration(seconds: 4));

      _subscription = _channel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data.toString()) as Map<String, dynamic>;
            final event = msg['event'];
            if (event == 'progress') {
              final pct = (msg['progress'] as num?)?.toDouble() ?? 0.0;
              final currentCm = (msg['currentCm'] as num?)?.toInt() ?? (pct * lengthCm).round();
              onProgress(pct, currentCm);
            } else if (event == 'complete' || msg['status'] == 'success') {
              onProgress(1.0, lengthCm);
              if (!completer.isCompleted) completer.complete(true);
            } else if (event == 'error') {
              if (!completer.isCompleted) completer.complete(false);
            }
          } catch (_) {}
        },
        onError: (_) {
          if (!completer.isCompleted) completer.complete(false);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete(false);
        },
      );

      // Send command
      _channel!.sink.add(jsonEncode({
        'action': 'dispense',
        'lengthCm': lengthCm,
      }));

      return await completer.future.timeout(const Duration(seconds: 15), onTimeout: () => false);
    } catch (_) {
      return false;
    } finally {
      _cleanup();
    }
  }

  @override
  Future<void> stop() async {
    try {
      _channel?.sink.add(jsonEncode({'action': 'stop'}));
    } catch (_) {}
    _cleanup();
  }

  void _cleanup() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  @override
  void dispose() {
    _cleanup();
  }
}
