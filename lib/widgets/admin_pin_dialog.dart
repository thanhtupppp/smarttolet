import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/kiosk_theme.dart';

class AdminPinDialog extends StatefulWidget {
  final String expectedPin;
  final VoidCallback onSuccess;
  final int maxAttempts;
  final int lockoutSeconds;

  const AdminPinDialog({
    super.key,
    required this.expectedPin,
    required this.onSuccess,
    this.maxAttempts = 5,
    this.lockoutSeconds = 30,
  });

  @override
  State<AdminPinDialog> createState() => _AdminPinDialogState();
}

class _AdminPinDialogState extends State<AdminPinDialog> {
  String _enteredPin = '';
  int _failedAttempts = 0;
  int _lockoutRemaining = 0;
  Timer? _lockoutTimer;
  String? _statusError;

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (_lockoutRemaining > 0) return;
    if (_enteredPin.length >= widget.expectedPin.length) return;

    setState(() {
      _enteredPin += digit;
      _statusError = null;
    });

    if (_enteredPin.length == widget.expectedPin.length) {
      _verifyPin();
    }
  }

  void _onDelete() {
    if (_lockoutRemaining > 0 || _enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _statusError = null;
    });
  }

  void _onClear() {
    if (_lockoutRemaining > 0) return;
    setState(() {
      _enteredPin = '';
      _statusError = null;
    });
  }

  void _verifyPin() {
    if (_enteredPin == widget.expectedPin) {
      Navigator.of(context).pop();
      widget.onSuccess();
    } else {
      setState(() {
        _failedAttempts++;
        _enteredPin = '';
        _statusError = 'Mật khẩu không đúng! ($_failedAttempts/${widget.maxAttempts})';
      });

      if (_failedAttempts >= widget.maxAttempts) {
        _startLockout();
      }
    }
  }

  void _startLockout() {
    setState(() {
      _lockoutRemaining = widget.lockoutSeconds;
      _statusError = 'Đã thử sai quá nhiều lần. Khóa $_lockoutRemaining giây!';
    });

    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lockoutRemaining <= 1) {
        timer.cancel();
        setState(() {
          _lockoutRemaining = 0;
          _failedAttempts = 0;
          _statusError = null;
        });
      } else {
        setState(() {
          _lockoutRemaining--;
          _statusError = 'Đã thử sai quá nhiều lần. Khóa $_lockoutRemaining giây!';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pinLength = widget.expectedPin.length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(28),
        decoration: KioskTheme.glowBox(
          glowColor: _statusError != null ? KioskTheme.errorRed : KioskTheme.primaryCyan,
          radius: 28,
          bgColor: KioskTheme.surfaceElevated,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.admin_panel_settings_rounded, color: KioskTheme.primaryCyan, size: 24),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'XÁC THỰC ADMIN',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: KioskTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: KioskTheme.textSecondary, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text(
              'Nhập mã PIN 4 số để vào cài đặt cấu hình',
              style: TextStyle(
                color: KioskTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),

            // PIN Dots Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pinLength, (index) {
                final isFilled = index < _enteredPin.length;
                return Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? KioskTheme.primaryCyan : Colors.transparent,
                    border: Border.all(
                      color: isFilled ? KioskTheme.primaryCyan : KioskTheme.textMuted,
                      width: 2,
                    ),
                    boxShadow: isFilled
                        ? [
                            BoxShadow(
                              color: KioskTheme.primaryCyan.withValues(alpha: 0.6),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // Status error message
            if (_statusError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _statusError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: KioskTheme.errorRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            // Numeric Keypad
            _buildKeypad(),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', '⌫'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) {
              final isLocked = _lockoutRemaining > 0;
              final isAction = key == 'C' || key == '⌫';

              return SizedBox(
                width: 72,
                height: 56,
                child: Material(
                  color: isAction
                      ? KioskTheme.surface.withValues(alpha: 0.6)
                      : KioskTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: isLocked
                        ? null
                        : () {
                            if (key == 'C') {
                              _onClear();
                            } else if (key == '⌫') {
                              _onDelete();
                            } else {
                              _onDigitPressed(key);
                            }
                          },
                    child: Center(
                      child: Text(
                        key,
                        style: TextStyle(
                          color: isLocked
                              ? KioskTheme.textMuted
                              : (isAction ? KioskTheme.primaryCyan : KioskTheme.textPrimary),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
