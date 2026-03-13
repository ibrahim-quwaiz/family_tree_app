import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ═══════════════════════════════════════════
// الألوان الديناميكية — تتغير حسب الثيم
// ═══════════════════════════════════════════
class AppColors {
  // المُزوّد الحالي (داكن افتراضياً)
  static _AppColorSet _current = _DarkColors();

  static void setDark() => _current = _DarkColors();
  static void setLight() => _current = _LightColors();

  // الألوان الأساسية (ثابتة في كلا الثيمين)
  static const gold = Color(0xFFC8A45C);
  static const goldLight = Color(0xFFE8D5A3);
  static const goldDark = Color(0xFF9A7B3A);
  static const accentGreen = Color(0xFF4CAF7D);
  static const accentBlue = Color(0xFF4A8FD4);
  static const accentRed = Color(0xFFD4654A);
  static const accentPurple = Color(0xFF8B6AC2);
  static const accentTeal = Color(0xFF4ABDD4);
  static const accentAmber = Color(0xFFD4A44A);
  static const successGreen = Color(0xFF22C55E);
  static const neutralGray = Color(0xFF6B7280);
  static const primaryGreen = accentGreen;
  static const secondaryGold = gold;

  // الألوان الديناميكية
  static Color get bgDeep => _current.bgDeep;
  static Color get bgCard => _current.bgCard;
  static Color get bgCardHover => _current.bgCardHover;
  static Color get textPrimary => _current.textPrimary;
  static Color get textSecondary => _current.textSecondary;
  static Color get borderLight => _current.borderLight;
  static Color get cardBorder => _current.borderLight;
  static Color get background => _current.bgDeep;
  static Color get surface => _current.bgCard;
}

// ═══════════════════════════════════════════
// Interface
// ═══════════════════════════════════════════
abstract class _AppColorSet {
  Color get bgDeep;
  Color get bgCard;
  Color get bgCardHover;
  Color get textPrimary;
  Color get textSecondary;
  Color get borderLight;
}

// ═══════════════════════════════════════════
// الثيم الداكن
// ═══════════════════════════════════════════
class _DarkColors implements _AppColorSet {
  @override Color get bgDeep => const Color(0xFF0A1628);
  @override Color get bgCard => const Color(0xFF111E36);
  @override Color get bgCardHover => const Color(0xFF162747);
  @override Color get textPrimary => const Color(0xFFF0EDE6);
  @override Color get textSecondary => const Color(0xFF8A9BB5);
  @override Color get borderLight => const Color(0xFF1E3050);
}

// ═══════════════════════════════════════════
// الثيم الفاتح
// ═══════════════════════════════════════════
class _LightColors implements _AppColorSet {
  @override Color get bgDeep => const Color(0xFFF0F2F5);
  @override Color get bgCard => const Color(0xFFFFFFFF);
  @override Color get bgCardHover => const Color(0xFFE8ECF0);
  @override Color get textPrimary => const Color(0xFF1A1A2E);
  @override Color get textSecondary => const Color(0xFF6C757D);
  @override Color get borderLight => const Color(0xFFDEE2E6);
}

// ═══════════════════════════════════════════
// AppTheme
// ═══════════════════════════════════════════
class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      textTheme: GoogleFonts.tajawalTextTheme(ThemeData.dark().textTheme),
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        secondary: AppColors.accentGreen,
        surface: Color(0xFF111E36),
        onPrimary: Color(0xFF0A1628),
        onSecondary: Colors.white,
        onSurface: Color(0xFFF0EDE6),
      ),
      scaffoldBackgroundColor: const Color(0xFF0A1628),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0A1628),
        foregroundColor: Color(0xFFF0EDE6),
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.gold),
        titleTextStyle: TextStyle(
          color: Color(0xFFF0EDE6),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF111E36),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.04)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF0A1628),
        selectedItemColor: AppColors.gold,
        unselectedItemColor: Color(0xFF4A5568),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF111E36),
        hintStyle: TextStyle(color: Color(0xFF8A9BB5)),
        labelStyle: TextStyle(color: Color(0xFF8A9BB5)),
        prefixIconColor: const Color(0xFF8A9BB5),
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
      listTileTheme: const ListTileThemeData(
        textColor: Color(0xFFF0EDE6),
        iconColor: AppColors.gold,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: Color(0xFF0A1628),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.gold,
          side: const BorderSide(color: AppColors.gold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      dividerTheme: DividerThemeData(color: Colors.white.withOpacity(0.06)),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF111E36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF111E36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.gold),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF162747),
        contentTextStyle: TextStyle(color: Color(0xFFF0EDE6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF111E36),
        foregroundColor: AppColors.gold,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      textTheme: GoogleFonts.tajawalTextTheme(ThemeData.light().textTheme),
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.gold,
        secondary: AppColors.accentGreen,
        surface: Color(0xFFFFFFFF),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF1A1A2E),
      ),
      scaffoldBackgroundColor: const Color(0xFFF0F2F5),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF0F2F5),
        foregroundColor: Color(0xFF1A1A2E),
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.gold),
        titleTextStyle: TextStyle(
          color: Color(0xFF1A1A2E),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: Color(0xFFADB5BD),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: TextStyle(color: Color(0xFFADB5BD)),
        labelStyle: TextStyle(color: Color(0xFF6C757D)),
        prefixIconColor: const Color(0xFF6C757D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: Color(0xFF1A1A2E),
        iconColor: AppColors.gold,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.gold,
          side: const BorderSide(color: AppColors.gold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFDEE2E6)),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.gold),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF2D3748),
        contentTextStyle: TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.gold,
      ),
    );
  }
}
