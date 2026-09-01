import 'package:flutter/material.dart';
import '../theme/kiosk_theme.dart';

class HiddenTriggerButton extends StatefulWidget {
  final VoidCallback onTriggered;
  final Duration holdDuration;

  const HiddenTriggerButton({
    super.key,
    required this.onTriggered,
    this.holdDuration = const Duration(seconds: 3),
  });

  @override
  State<HiddenTriggerButton> createState() => _HiddenTriggerButtonState();
}

class _HiddenTriggerButtonState extends State<HiddenTriggerButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _holdController;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    );

    _holdController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _isCompleted = true;
        widget.onTriggered();
      }
    });
  }

  @override
  void dispose() {
    _holdController.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    _isCompleted = false;
    _holdController.forward();
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_isCompleted) {
      _holdController.reset();
      _isCompleted = false;
    } else {
      _holdController.reverse();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_isCompleted) {
      _holdController.reset();
      _isCompleted = false;
    } else {
      _holdController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: AnimatedBuilder(
        animation: _holdController,
        builder: (context, child) {
          final isHolding = _holdController.value > 0.0;
          return Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isHolding
                  ? KioskTheme.primaryCyan.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.3),
              border: Border.all(
                color: isHolding
                    ? KioskTheme.primaryCyan
                    : Colors.white.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isHolding)
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      value: _holdController.value,
                      strokeWidth: 3.5,
                      valueColor: const AlwaysStoppedAnimation<Color>(KioskTheme.primaryCyan),
                    ),
                  ),
                Icon(
                  Icons.settings_outlined,
                  color: isHolding ? KioskTheme.primaryCyan : Colors.white54,
                  size: 22,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
