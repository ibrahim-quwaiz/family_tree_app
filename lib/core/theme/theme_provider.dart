import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _key = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key) ?? 'dark';
    _themeMode = _fromString(saved);
    _applyColors();
    notifyListeners();
  }

  void _applyColors() {
    if (_themeMode == ThemeMode.dark) {
      AppColors.setDark();
    } else if (_themeMode == ThemeMode.light) {
      AppColors.setLight();
    } else {
      final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      brightness == Brightness.dark ? AppColors.setDark() : AppColors.setLight();
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;
    _applyColors();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _toString(mode));
  }

  ThemeMode _fromString(String value) {
    switch (value) {
      case 'light': return ThemeMode.light;
      case 'system': return ThemeMode.system;
      default: return ThemeMode.dark;
    }
  }

  String _toString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light: return 'light';
      case ThemeMode.system: return 'system';
      default: return 'dark';
    }
  }
}
