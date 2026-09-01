class DispenseRecord {
  final String id;
  final DateTime timestamp;
  final int lengthCm;
  final bool isSuccess;
  final String mode;
  final String? errorMessage;

  const DispenseRecord({
    required this.id,
    required this.timestamp,
    required this.lengthCm,
    required this.isSuccess,
    required this.mode,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'lengthCm': lengthCm,
      'isSuccess': isSuccess,
      'mode': mode,
      'errorMessage': errorMessage,
    };
  }

  factory DispenseRecord.fromJson(Map<String, dynamic> json) {
    return DispenseRecord(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      lengthCm: json['lengthCm'] as int,
      isSuccess: json['isSuccess'] as bool,
      mode: json['mode'] as String,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}
