import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'app_theme';
  static const String _fontSizeKey = 'app_font_size';
  static const String _localeKey = 'app_locale';

  ThemeMode _themeMode = ThemeMode.dark;
  double _fontSize = 16.0;
  Locale _locale = const Locale('tr');

  ThemeMode get themeMode => _themeMode;
  double get fontSize => _fontSize;
  bool get isDark => _themeMode == ThemeMode.dark;
  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;

  ThemeProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString(_themeKey) ?? 'dark';
    _themeMode = theme == 'light' ? ThemeMode.light : ThemeMode.dark;
    _fontSize = prefs.getDouble(_fontSizeKey) ?? 16.0;
    final lang = prefs.getString(_localeKey) ?? 'tr';
    _locale = Locale(lang);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode == ThemeMode.light ? 'light' : 'dark');
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    await setThemeMode(_themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, size);
    notifyListeners();
  }

  Future<void> setLocale(String languageCode) async {
    _locale = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, languageCode);
    notifyListeners();
  }

  ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF1A1A1A),
    colorScheme: const ColorScheme.dark(
      surface: Color(0xFF1A1A1A),
      primary: Color(0xFFC9A96E),
      onPrimary: Color(0xFF1A1A1A),
      secondary: Color(0xFFC9A96E),
    ),
    useMaterial3: true,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1A1A1A),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 16,
        fontWeight: FontWeight.w300,
        color: Color(0xFFD4D4D4),
        letterSpacing: 0.5,
      ),
      iconTheme: IconThemeData(color: Color(0xFF888888)),
    ),
    dividerColor: const Color(0xFF333333),
    cardTheme: const CardThemeData(
      color: Color(0xFF242424),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Color(0xFF333333)),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontWeight: FontWeight.w300, letterSpacing: -0.5),
      headlineMedium: TextStyle(fontWeight: FontWeight.w300, letterSpacing: -0.5),
      bodyLarge: TextStyle(fontWeight: FontWeight.w300, color: Color(0xFFD4D4D4)),
      bodyMedium: TextStyle(fontWeight: FontWeight.w300, color: Color(0xFFD4D4D4)),
    ),
  );

  ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    colorScheme: const ColorScheme.light(
      surface: Color(0xFFF5F5F5),
      primary: Color(0xFF8B7355),
      onPrimary: Colors.white,
      secondary: Color(0xFF8B7355),
    ),
    useMaterial3: true,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF5F5F5),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 16,
        fontWeight: FontWeight.w300,
        color: Color(0xFF333333),
        letterSpacing: 0.5,
      ),
      iconTheme: IconThemeData(color: Color(0xFF666666)),
    ),
    dividerColor: const Color(0xFFDDDDDD),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Color(0xFFDDDDDD)),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontWeight: FontWeight.w300, letterSpacing: -0.5),
      headlineMedium: TextStyle(fontWeight: FontWeight.w300, letterSpacing: -0.5),
      bodyLarge: TextStyle(fontWeight: FontWeight.w300, color: Color(0xFF333333)),
      bodyMedium: TextStyle(fontWeight: FontWeight.w300, color: Color(0xFF333333)),
    ),
  );
}
