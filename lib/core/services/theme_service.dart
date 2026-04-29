import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme.dart';

class ThemeService {
  static const String _key = 'is_dark_mode';
  
  static Future<bool> isDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }
  
  static Future<void> setDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, isDark);
  }
  
  static ThemeData getLightTheme() {
    return posTheme;
  }
  
  static ThemeData getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: PosColors.primary,
      colorScheme: const ColorScheme.dark(
        primary: PosColors.primary,
        secondary: PosColors.info,
        surface: Color(0xFF1E1E2E),
      ),
      scaffoldBackgroundColor: const Color(0xFF12121A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E2E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E2E),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2D2D3A)),
        ),
      ),
    );
  }
}