import 'package:flutter/material.dart';

class KioskTheme {
  // Brand Palette
  static const Color background = Color(0xFF0B0F19);
  static const Color surface = Color(0xFF131B2E);
  static const Color surfaceElevated = Color(0xFF1E293B);
  static const Color cardBg = Color(0xFF162036);
  
  static const Color primaryCyan = Color(0xFF00E5FF);
  static const Color accentGreen = Color(0xFF00E676);
  static const Color warningAmber = Color(0xFFFFB300);
  static const Color errorRed = Color(0xFFFF1744);
  static const Color purpleNeon = Color(0xFF7C4DFF);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primaryCyan,
      fontFamily: 'Segoe UI', // Clean modern fallback
      colorScheme: const ColorScheme.dark(
        primary: primaryCyan,
        secondary: accentGreen,
        surface: surface,
        error: errorRed,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: primaryCyan.withValues(alpha: 0.15), width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  // Common BoxDecorations with Neon Glow
  static BoxDecoration glowBox({
    Color glowColor = primaryCyan,
    double radius = 16,
    Color bgColor = surface,
    double glowSpread = 2,
    double glowBlur = 16,
  }) {
    return BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: glowColor.withValues(alpha: 0.6),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: glowColor.withValues(alpha: 0.25),
          blurRadius: glowBlur,
          spreadRadius: glowSpread,
        ),
      ],
    );
  }
}
