class UsageStats {
  final int? id;
  final String deviceId;
  final String date; // YYYY-MM-DD
  final int totalEvents;
  final int totalPaperCm;
  final int successCount;
  final int failCount;

  const UsageStats({
    this.id,
    required this.deviceId,
    required this.date,
    this.totalEvents = 0,
    this.totalPaperCm = 0,
    this.successCount = 0,
    this.failCount = 0,
  });

  double get totalMeters => totalPaperCm / 100.0;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'device_id': deviceId,
      'date': date,
      'total_events': totalEvents,
      'total_paper_cm': totalPaperCm,
      'success_count': successCount,
      'fail_count': failCount,
    };
  }

  factory UsageStats.fromMap(Map<String, dynamic> map) {
    return UsageStats(
      id: map['id'] as int?,
      deviceId: map['device_id'] as String? ?? 'kiosk_main',
      date: map['date'] as String,
      totalEvents: (map['total_events'] as num?)?.toInt() ?? 0,
      totalPaperCm: (map['total_paper_cm'] as num?)?.toInt() ?? 0,
      successCount: (map['success_count'] as num?)?.toInt() ?? 0,
      failCount: (map['fail_count'] as num?)?.toInt() ?? 0,
    );
  }
}
