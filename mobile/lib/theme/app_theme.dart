import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const red = Color(0xFFDC2626);
  static const redLight = Color(0xFFEF4444);
  static const redDark = Color(0xFFB91C1C);

  // Surface - crypto dark theme
  static const surface950 = Color(0xFF070B14);
  static const surface900 = Color(0xFF0C1322);
  static const surface800 = Color(0xFF131C2E);
  static const surface700 = Color(0xFF1E293B);
  static const surface600 = Color(0xFF334155);
  static const surface500 = Color(0xFF475569);
  static const surface400 = Color(0xFF64748B);
  static const surface300 = Color(0xFF94A3B8);
  static const surface200 = Color(0xFFCBD5E1);

  // Status
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.surface950,
      colorScheme: ColorScheme.dark(
        primary: AppColors.red,
        secondary: AppColors.redLight,
        surface: AppColors.surface900,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
      ),
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface950,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface800.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.surface700.withValues(alpha: 0.5)),
        ),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface900.withValues(alpha: 0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.surface700.withValues(alpha: 0.6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.surface700.withValues(alpha: 0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.red.withValues(alpha: 0.5)),
        ),
        hintStyle: TextStyle(color: AppColors.surface500),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.red,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface900,
        indicatorColor: AppColors.red.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.red,
            );
          }
          return const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.surface400,
          );
        }),
      ),
      dividerColor: AppColors.surface700.withValues(alpha: 0.5),
    );
  }
}
