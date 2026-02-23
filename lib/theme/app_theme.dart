import 'package:flutter/material.dart';

/// Clinic app theme using Medical Blue / Medical Green palette.
/// Light and dark palettes from design spec.
class AppTheme {
  // ─── Light mode (Clinic App) ─────────────────────────────────────────────
  static const Color _lightPrimary = Color(0xFF2563EB);           // Medical Blue
  static const Color _lightPrimaryVariant = Color(0xFF1E40AF);   // Dark Blue
  static const Color _lightSecondary = Color(0xFF108981);         // Medical Green
  static const Color _lightBackground = Color(0xFFF8FAFC);        // Soft Gray
  static const Color _lightSurface = Color(0xFFFFFFFF);           // White
  static const Color _lightTextPrimary = Color(0xFF0F172A);       // Dark Gray
  static const Color _lightTextSecondary = Color(0xFF647488);     // Medium Gray
  static const Color _lightBorder = Color(0xFFE2E8F0);            // Light Gray
  static const Color _lightError = Color(0xFFEF4444);             // Medical Red

  // ─── Dark mode (Clinic App) ─────────────────────────────────────────────
  static const Color _darkPrimary = Color(0xFF60A5FA);           // Light Medical Blue
  static const Color _darkPrimaryVariant = Color(0xFF3BB2F6);     // Blue
  static const Color _darkSecondary = Color(0xFF14B8A6);          // Teal (Medical Green in dark; #340399 is purple, using teal for consistency)
  static const Color _darkBackground = Color(0xFF0F172A);         // Dark Blue Gray
  static const Color _darkSurface = Color(0xFF1E293B);            // Dark Surface
  static const Color _darkTextPrimary = Color(0xFFF1F5F9);        // White
  static const Color _darkTextSecondary = Color(0xFF94A3B8);       // Gray (readable)
  static const Color _darkBorder = Color(0xFF334155);             // Dark Border
  static const Color _darkError = Color(0xFFF87171);              // Soft Red

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _lightBackground,
      colorScheme: ColorScheme.light(
        primary: _lightPrimary,
        onPrimary: Colors.white,
        primaryContainer: _lightPrimaryVariant,
        onPrimaryContainer: Colors.white,
        secondary: _lightSecondary,
        onSecondary: Colors.white,
        surface: _lightSurface,
        onSurface: _lightTextPrimary,
        onSurfaceVariant: _lightTextSecondary,
        outline: _lightBorder,
        error: _lightError,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: _lightSurface,
        foregroundColor: _lightTextPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: _lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: _lightSurface,
        focusColor: _lightPrimary,
      ),
      textTheme: Typography.material2021().black,
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _darkBackground,
      colorScheme: ColorScheme.dark(
        primary: _darkPrimary,
        onPrimary: _darkBackground,
        primaryContainer: _darkPrimaryVariant,
        onPrimaryContainer: _darkBackground,
        secondary: _darkSecondary,
        onSecondary: _darkBackground,
        surface: _darkSurface,
        onSurface: _darkTextPrimary,
        onSurfaceVariant: _darkTextSecondary,
        outline: _darkBorder,
        error: _darkError,
        onError: _darkBackground,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: _darkSurface,
        foregroundColor: _darkTextPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: _darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: _darkSurface,
        focusColor: _darkPrimary,
      ),
      textTheme: Typography.material2021().white,
    );
  }
}
