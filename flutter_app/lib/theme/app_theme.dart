import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF262421),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF81B64C),
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF81B64C),
      secondary: const Color(0xFFF1C453),
      surface: const Color(0xFF312E2B),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1F1D1B),
      foregroundColor: Colors.white,
    ),
    cardTheme: const CardTheme(
      color: Color(0xFF312E2B),
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: Color(0xFF3C3936)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF3A3836),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFF4A4743)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFF4A4743)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFF81B64C), width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF81B64C),
        foregroundColor: const Color(0xFF1F1D1B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  );
}
