import 'kiosk_state.dart';

class DispenserConfig {
  final int paperLengthCm;
  final int cooldownMinutes;
  final ConnectionMode connectionMode;
  final String espIp;
  final int espPort;
  final String espWsUrl;
  final int pulsePerCm;
  final String adminPin;
  final int totalRollCapacityMeters;
  final double paperUsedMeters;

  const DispenserConfig({
    this.paperLengthCm = 70,
    this.cooldownMinutes = 9,
    this.connectionMode = ConnectionMode.demo,
    this.espIp = '192.168.4.1',
    this.espPort = 80,
    this.espWsUrl = 'ws://192.168.4.1/ws',
    this.pulsePerCm = 10,
    this.adminPin = '1234',
    this.totalRollCapacityMeters = 100,
    this.paperUsedMeters = 0.0,
  });

  double get remainingPercentage {
    if (totalRollCapacityMeters <= 0) return 0.0;
    final remaining = totalRollCapacityMeters - paperUsedMeters;
    final pct = (remaining / totalRollCapacityMeters) * 100;
    return pct.clamp(0.0, 100.0);
  }

  DispenserConfig copyWith({
    int? paperLengthCm,
    int? cooldownMinutes,
    ConnectionMode? connectionMode,
    String? espIp,
    int? espPort,
    String? espWsUrl,
    int? pulsePerCm,
    String? adminPin,
    int? totalRollCapacityMeters,
    double? paperUsedMeters,
  }) {
    return DispenserConfig(
      paperLengthCm: paperLengthCm ?? this.paperLengthCm,
      cooldownMinutes: cooldownMinutes ?? this.cooldownMinutes,
      connectionMode: connectionMode ?? this.connectionMode,
      espIp: espIp ?? this.espIp,
      espPort: espPort ?? this.espPort,
      espWsUrl: espWsUrl ?? this.espWsUrl,
      pulsePerCm: pulsePerCm ?? this.pulsePerCm,
      adminPin: adminPin ?? this.adminPin,
      totalRollCapacityMeters: totalRollCapacityMeters ?? this.totalRollCapacityMeters,
      paperUsedMeters: paperUsedMeters ?? this.paperUsedMeters,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'paperLengthCm': paperLengthCm,
      'cooldownMinutes': cooldownMinutes,
      'connectionMode': connectionMode.name,
      'espIp': espIp,
      'espPort': espPort,
      'espWsUrl': espWsUrl,
      'pulsePerCm': pulsePerCm,
      'adminPin': adminPin,
      'totalRollCapacityMeters': totalRollCapacityMeters,
      'paperUsedMeters': paperUsedMeters,
    };
  }

  factory DispenserConfig.fromJson(Map<String, dynamic> json) {
    return DispenserConfig(
      paperLengthCm: json['paperLengthCm'] as int? ?? 70,
      cooldownMinutes: json['cooldownMinutes'] as int? ?? 9,
      connectionMode: ConnectionMode.values.firstWhere(
        (e) => e.name == json['connectionMode'],
        orElse: () => ConnectionMode.demo,
      ),
      espIp: json['espIp'] as String? ?? '192.168.4.1',
      espPort: json['espPort'] as int? ?? 80,
      espWsUrl: json['espWsUrl'] as String? ?? 'ws://192.168.4.1/ws',
      pulsePerCm: json['pulsePerCm'] as int? ?? 10,
      adminPin: json['adminPin'] as String? ?? '1234',
      totalRollCapacityMeters: json['totalRollCapacityMeters'] as int? ?? 100,
      paperUsedMeters: (json['paperUsedMeters'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
