import 'package:flutter/material.dart';

class AppColors {
  static const background  = Color(0xFF0D0F17);
  static const surface     = Color(0xFF131520);
  static const surfaceHigh = Color(0xFF1A1D2E);
  static const border      = Color(0x1AFFFFFF);
  static const primary     = Color(0xFF6C63FF);
  static const income      = Color(0xFF22C55E);
  static const expense     = Color(0xFFEF4444);
  static const pending     = Color(0xFFF59E0B);
  static const textPrimary   = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF9CA3AF);
  static const textMuted     = Color(0xFF6B7280);
}

ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.primary,
    surface: AppColors.surface,
    error: AppColors.expense,
  ),
  fontFamily: 'Roboto',
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceHigh,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Color(0xE6131520),
    selectedItemColor: AppColors.primary,
    unselectedItemColor: AppColors.textMuted,
    showSelectedLabels: true,
    showUnselectedLabels: true,
    type: BottomNavigationBarType.fixed,
    elevation: 0,
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: AppColors.surfaceHigh,
    contentTextStyle: const TextStyle(color: AppColors.textPrimary),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    behavior: SnackBarBehavior.floating,
  ),
);
