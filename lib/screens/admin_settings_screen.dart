import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/kiosk_controller.dart';
import '../models/kiosk_state.dart';
import '../theme/kiosk_theme.dart';
import '../widgets/stats_summary_card.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  late int _paperLengthCm;
  late int _cooldownMinutes;
  late ConnectionMode _connectionMode;
  late TextEditingController _espIpController;
  late TextEditingController _espPortController;
  late TextEditingController _espWsUrlController;
  late TextEditingController _pulsePerCmController;
  late TextEditingController _adminPinController;

  bool _isTestingHealth = false;
  bool? _healthResult;
  bool _isTestingDispense = false;

  @override
  void initState() {
    super.initState();
    final config = context.read<KioskController>().config;
    _paperLengthCm = config.paperLengthCm;
    _cooldownMinutes = config.cooldownMinutes;
    _connectionMode = config.connectionMode;
    _espIpController = TextEditingController(text: config.espIp);
    _espPortController = TextEditingController(text: config.espPort.toString());
    _espWsUrlController = TextEditingController(text: config.espWsUrl);
    _pulsePerCmController = TextEditingController(text: config.pulsePerCm.toString());
    _adminPinController = TextEditingController(text: config.adminPin);
  }

  @override
  void dispose() {
    _espIpController.dispose();
    _espPortController.dispose();
    _espWsUrlController.dispose();
    _pulsePerCmController.dispose();
    _adminPinController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final controller = context.read<KioskController>();
    final newConfig = controller.config.copyWith(
      paperLengthCm: _paperLengthCm,
      cooldownMinutes: _cooldownMinutes,
      connectionMode: _connectionMode,
      espIp: _espIpController.text.trim(),
      espPort: int.tryParse(_espPortController.text.trim()) ?? 80,
      espWsUrl: _espWsUrlController.text.trim(),
      pulsePerCm: int.tryParse(_pulsePerCmController.text.trim()) ?? 10,
      adminPin: _adminPinController.text.trim().isNotEmpty
          ? _adminPinController.text.trim()
          : '1234',
    );

    await controller.updateConfig(newConfig);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: KioskTheme.accentGreen),
              SizedBox(width: 10),
              Text('Đã lưu cấu hình Kiosk thành công!'),
            ],
          ),
          backgroundColor: KioskTheme.surfaceElevated,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingHealth = true;
      _healthResult = null;
    });

    final controller = context.read<KioskController>();
    final isHealthy = await controller.driver.checkHealth();

    if (mounted) {
      setState(() {
        _isTestingHealth = false;
        _healthResult = isHealthy;
      });
    }
  }

  Future<void> _testManualDispense() async {
    setState(() {
      _isTestingDispense = true;
    });

    final controller = context.read<KioskController>();
    final success = await controller.driver.dispense(
      lengthCm: 10,
      onProgress: (_, _) {},
    );

    if (mounted) {
      setState(() {
        _isTestingDispense = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Test nhả 10cm thành công!' : 'Lỗi test nhả giấy!'),
          backgroundColor: success ? KioskTheme.accentGreen : KioskTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<KioskController>();
    final config = controller.config;

    return Scaffold(
      backgroundColor: KioskTheme.background,
      appBar: AppBar(
        title: const Text('BẢNG ĐIỀU KHIỂN ADMIN'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: KioskTheme.primaryCyan),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Lưu cấu hình',
            icon: const Icon(Icons.save_rounded, color: KioskTheme.primaryCyan),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Section: Summary statistics
          StatsSummaryCard(
            todayUses: 1,
            todayMeters: (config.paperUsedMeters).toStringAsFixed(1),
            remainingPercentage: config.remainingPercentage,
            onResetRoll: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              await controller.resetPaperRoll();
              scaffoldMessenger.showSnackBar(
                const SnackBar(content: Text('Đã đặt lại cuộn giấy 100%!')),
              );
            },
          ),
          const SizedBox(height: 24),

          // Section 1: Dispense Configuration
          _buildCard(
            title: '1. CẤU HÌNH CẤP GIẤY',
            icon: Icons.straighten_rounded,
            children: [
              // Paper length slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Chiều dài giấy mỗi lần cấp:', style: TextStyle(color: KioskTheme.textSecondary)),
                  Text(
                    '$_paperLengthCm cm',
                    style: const TextStyle(
                      color: KioskTheme.primaryCyan,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _paperLengthCm.toDouble(),
                min: 30,
                max: 150,
                divisions: 24,
                activeColor: KioskTheme.primaryCyan,
                inactiveColor: KioskTheme.surface,
                onChanged: (val) => setState(() => _paperLengthCm = val.round()),
              ),
              const SizedBox(height: 12),

              // Cooldown slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Thời gian chờ Cooldown:', style: TextStyle(color: KioskTheme.textSecondary)),
                  Text(
                    '$_cooldownMinutes phút',
                    style: const TextStyle(
                      color: KioskTheme.warningAmber,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _cooldownMinutes.toDouble(),
                min: 1,
                max: 60,
                divisions: 59,
                activeColor: KioskTheme.warningAmber,
                inactiveColor: KioskTheme.surface,
                onChanged: (val) => setState(() => _cooldownMinutes = val.round()),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section 2: Hardware Connection Mode
          _buildCard(
            title: '2. GIAO TIẾP VỚI ESP32',
            icon: Icons.router_outlined,
            children: [
              const Text(
                'Chọn phương thức kết nối điều khiển motor:',
                style: TextStyle(color: KioskTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),

              // Connection Mode selector chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ConnectionMode.values.map((mode) {
                  final isSelected = _connectionMode == mode;
                  return ChoiceChip(
                    label: Text(
                      _modeLabel(mode),
                      style: TextStyle(
                        color: isSelected ? Colors.black : KioskTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: KioskTheme.primaryCyan,
                    backgroundColor: KioskTheme.surface,
                    onSelected: (selected) {
                      if (selected) setState(() => _connectionMode = mode);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // IP / Port inputs for HTTP / WS
              if (_connectionMode == ConnectionMode.http || _connectionMode == ConnectionMode.demo) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _espIpController,
                        decoration: _inputDecoration('Địa chỉ IP ESP32 (vd: 192.168.4.1)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _espPortController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration('Port (80)'),
                      ),
                    ),
                  ],
                ),
              ],

              if (_connectionMode == ConnectionMode.websocket) ...[
                TextField(
                  controller: _espWsUrlController,
                  decoration: _inputDecoration('WebSocket URL (ws://192.168.4.1/ws)'),
                ),
              ],
              const SizedBox(height: 14),

              // Health check & test button
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _isTestingHealth ? null : _testConnection,
                    icon: _isTestingHealth
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_ping_rounded, size: 18),
                    label: const Text('Kiểm tra kết nối'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: KioskTheme.primaryCyan,
                      side: const BorderSide(color: KioskTheme.primaryCyan),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_healthResult != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (_healthResult! ? KioskTheme.accentGreen : KioskTheme.errorRed)
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _healthResult! ? KioskTheme.accentGreen : KioskTheme.errorRed,
                        ),
                      ),
                      child: Text(
                        _healthResult! ? '🟢 ONLINE' : '🔴 OFFLINE',
                        style: TextStyle(
                          color: _healthResult! ? KioskTheme.accentGreen : KioskTheme.errorRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section 3: Motor & Encoder Calibration
          _buildCard(
            title: '3. HIỆU CHUẨN MOTOR & ENCODER',
            icon: Icons.tune_rounded,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pulsePerCmController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Số xung Encoder / 1 cm giấy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isTestingDispense ? null : _testManualDispense,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Test nhả 10cm'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KioskTheme.purpleNeon,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section 4: Security & PIN
          _buildCard(
            title: '4. BẢO MẬT & MÃ PIN ADMIN',
            icon: Icons.security_rounded,
            children: [
              TextField(
                controller: _adminPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: _inputDecoration('Mã PIN Admin mới (4 chữ số)'),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Save settings big button
          ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: KioskTheme.primaryCyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 22),
                SizedBox(width: 8),
                Text(
                  'LƯU CẤU HÌNH KIOSK',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _modeLabel(ConnectionMode mode) {
    switch (mode) {
      case ConnectionMode.demo:
        return 'Demo (Mô phỏng)';
      case ConnectionMode.http:
        return 'HTTP REST API';
      case ConnectionMode.websocket:
        return 'WebSocket Realtime';
      case ConnectionMode.mqtt:
        return 'MQTT Broker';
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: KioskTheme.textSecondary, fontSize: 13),
      filled: true,
      fillColor: KioskTheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: KioskTheme.primaryCyan, width: 1.5),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: KioskTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: KioskTheme.primaryCyan, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: KioskTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
