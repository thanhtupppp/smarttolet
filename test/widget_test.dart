import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_toilet_kiosk/theme/kiosk_theme.dart';

void main() {
  test('KioskTheme provides valid dark theme data', () {
    final theme = KioskTheme.darkTheme;
    expect(theme.brightness, equals(Brightness.dark));
    expect(theme.scaffoldBackgroundColor, equals(KioskTheme.background));
    expect(theme.primaryColor, equals(KioskTheme.primaryCyan));
  });
}
