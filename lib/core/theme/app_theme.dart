import 'package:flutter/material.dart';

class AppColors {
  // الألوان الأساسية - الثيم الداكن الذهبي
  static const gold = Color(0xFFC8A45C);
  static const goldLight = Color(0xFFE8D5A3);
  static const goldDark = Color(0xFF9A7B3A);
  
  // الخلفيات
  static const bgDeep = Color(0xFF0A1628);
  static const bgCard = Color(0xFF111E36);
  static const bgCardHover = Color(0xFF162747);
  
  // النصوص
  static const textPrimary = Color(0xFFF0EDE6);
  static const textSecondary = Color(0xFF8A9BB5);
  
  // الألوان المميزة
  static const accentGreen = Color(0xFF4CAF7D);
  static const accentBlue = Color(0xFF4A8FD4);
  static const accentRed = Color(0xFFD4654A);
  static const accentPurple = Color(0xFF8B6AC2);
  static const accentTeal = Color(0xFF4ABDD4);
  static const accentAmber = Color(0xFFD4A44A);
  
  // ألوان متوافقة مع الأسماء القديمة (للتوافق مع الكود الموجود)
  static const primaryGreen = accentGreen;
  static const secondaryGold = gold;
  static const background = bgDeep;
  static const surface = bgCard;
  static const successGreen = Color(0xFF22C55E);
  static const neutralGray = Color(0xFF6B7280);
  static const borderLight = Color(0xFF1E3050);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        secondary: AppColors.accentGreen,
        surface: AppColors.bgCard,
        onPrimary: AppColors.bgDeep,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.bgDeep,
      
      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.gold),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      
      // Cards
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.04)),
        ),
      ),
      
      // BottomNavigationBar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgDeep,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: Color(0xFF4A5568),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      
      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgCard,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIconColor: AppColors.textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
      ),
      
      // ListTile
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.textPrimary,
        subtitleTextStyle: const TextStyle(color: AppColors.textSecondary),
        iconColor: AppColors.gold,
      ),
      
      // FilledButton
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.bgDeep,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.gold,
          side: const BorderSide(color: AppColors.gold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.bgDeep,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      // Divider
      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(0.06),
      ),
      
      // BottomSheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      
      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      
      // CircularProgressIndicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.gold,
      ),
      
      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bgCardHover,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      
      // FloatingActionButton
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.bgCard,
        foregroundColor: AppColors.gold,
      ),
    );
  }
  
  // الحفاظ على lightTheme للتوافق (لكن لن يُستخدم)
  static ThemeData get lightTheme => darkTheme;
}
