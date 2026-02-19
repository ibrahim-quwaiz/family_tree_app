import 'package:flutter/material.dart';

class AppColors {
  static const primaryGreen = Color(0xFF1B4D3E);
  static const secondaryGold = Color(0xFFD4AF37);
  static const background = Color(0xFFF8F9FA);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF212529);
  static const textSecondary = Color(0xFF6C757D);
  static const successGreen = Color(0xFF22C55E);
  static const neutralGray = Color(0xFF9CA3AF);
  static const borderLight = Color(0xFFE9ECEF);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryGreen,
        secondary: AppColors.secondaryGold,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}