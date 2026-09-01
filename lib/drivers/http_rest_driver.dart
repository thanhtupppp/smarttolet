import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dispenser_driver.dart';

class HttpRestDriver implements DispenserDriver {
  final String baseUrl;
  final http.Client? client;

  HttpRestDriver({
    required this.baseUrl,
    this.client,
  });

  http.Client get _client => client ?? http.Client();

  @override
  String get name => 'HTTP REST API ($baseUrl)';

  @override
  Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse('$baseUrl/health');
      final response = await _client.get(uri).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> dispense({
    required int lengthCm,
    required ProgressCallback onProgress,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/dispense');
      // Simulate starting progress
      onProgress(0.1, (lengthCm * 0.1).round());

      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'lengthCm': lengthCm}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        onProgress(1.0, lengthCm);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      final uri = Uri.parse('$baseUrl/stop');
      await _client.post(uri).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  @override
  void dispose() {
    client?.close();
  }
}
