class DispenseEvent {
  final int? id;
  final String deviceId;
  final String? userFaceHash;
  final int paperLengthCm;
  final double? matchScore;
  final bool livenessPassed;
  final bool isSuccess;
  final String? errorMessage;
  final String connectionMode;
  final DateTime createdAt;

  const DispenseEvent({
    this.id,
    required this.deviceId,
    this.userFaceHash,
    required this.paperLengthCm,
    this.matchScore,
    this.livenessPassed = true,
    this.isSuccess = true,
    this.errorMessage,
    required this.connectionMode,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'device_id': deviceId,
      'user_face_hash': userFaceHash,
      'paper_length_cm': paperLengthCm,
      'match_score': matchScore,
      'liveness_passed': livenessPassed ? 1 : 0,
      'is_success': isSuccess ? 1 : 0,
      'error_message': errorMessage,
      'connection_mode': connectionMode,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory DispenseEvent.fromMap(Map<String, dynamic> map) {
    return DispenseEvent(
      id: map['id'] as int?,
      deviceId: map['device_id'] as String? ?? 'kiosk_main',
      userFaceHash: map['user_face_hash'] as String?,
      paperLengthCm: (map['paper_length_cm'] as num?)?.toInt() ?? 70,
      matchScore: (map['match_score'] as num?)?.toDouble(),
      livenessPassed: (map['liveness_passed'] as int?) == 1,
      isSuccess: (map['is_success'] as int?) == 1,
      errorMessage: map['error_message'] as String?,
      connectionMode: map['connection_mode'] as String? ?? 'demo',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
