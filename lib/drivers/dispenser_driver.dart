typedef ProgressCallback = void Function(double progress, int currentCm);

abstract class DispenserDriver {
  String get name;
  Future<bool> checkHealth();
  Future<bool> dispense({
    required int lengthCm,
    required ProgressCallback onProgress,
  });
  Future<void> stop();
  void dispose() {}
}
