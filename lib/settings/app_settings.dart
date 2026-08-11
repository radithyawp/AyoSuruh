import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AyoLanguage {
  indonesia,
  english,
}

class AppSettingsController extends ChangeNotifier {
  AppSettingsController._();

  static final AppSettingsController instance = AppSettingsController._();

  static const String _languageKey = 'app_language';
  static const String _themeModeKey = 'app_theme_mode';

  AyoLanguage _language = AyoLanguage.indonesia;
  ThemeMode _themeMode = ThemeMode.system;

  AyoLanguage get language => _language;
  ThemeMode get themeMode => _themeMode;
  Locale get locale => Locale(_language == AyoLanguage.english ? 'en' : 'id');
  String get localeCode => locale.languageCode;

  bool get isEnglish => _language == AyoLanguage.english;

  bool get isDarkMode {
    switch (_themeMode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    }
  }

  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? language = prefs.getString(_languageKey);
    final String? theme = prefs.getString(_themeModeKey);

    _language = language == 'en' ? AyoLanguage.english : AyoLanguage.indonesia;
    _themeMode = switch (theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setLanguage(AyoLanguage language) async {
    if (_language == language) return;
    _language = language;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language == AyoLanguage.english ? 'en' : 'id');
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_themeModeKey, value);
  }
}
