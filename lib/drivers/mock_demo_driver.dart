import 'dart:async';
import 'dispenser_driver.dart';

class MockDemoDriver implements DispenserDriver {
  @override
  String get name => 'Demo Mode (Simulation)';

  bool _isCancelled = false;
  final Duration stepDuration;

  MockDemoDriver({this.stepDuration = const Duration(milliseconds: 30)});

  @override
  Future<bool> checkHealth() async {
    // Demo mode is always healthy
    await Future.delayed(const Duration(milliseconds: 100));
    return true;
  }

  @override
  Future<bool> dispense({
    required int lengthCm,
    required ProgressCallback onProgress,
  }) async {
    _isCancelled = false;
    final totalSteps = 40;
    
    for (int step = 1; step <= totalSteps; step++) {
      if (_isCancelled) {
        return false;
      }
      await Future.delayed(stepDuration);
      final progress = step / totalSteps;
      final currentCm = (progress * lengthCm).round();
      onProgress(progress, currentCm);
    }

    return true;
  }

  @override
  Future<void> stop() async {
    _isCancelled = true;
  }

  @override
  void dispose() {
    _isCancelled = true;
  }
}
