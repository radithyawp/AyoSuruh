import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthPreferences {
  AuthPreferences._();

  static const String _rememberKey = 'auth_remember_me';
  static const String _emailKey = 'auth_remembered_email';
  static const String _legacyPasswordKey = 'auth_remembered_password';
  static const String _onboardingSeenKey = 'auth_onboarding_seen_v1';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Remember Me hanya mengontrol pemulihan session Supabase dan email.
  /// Password tidak disimpan oleh Ayo Suruh.
  static Future<bool> shouldRememberSession() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberKey) ?? true;
  }

  static Future<String?> rememberedEmail() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? value = prefs.getString(_emailKey)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// Menghapus credential lama yang sempat tersimpan oleh implementasi
  /// Remember Me sebelumnya. Method ini idempotent dan aman dipanggil berulang.
  static Future<void> clearLegacyStoredPassword() async {
    try {
      await _secureStorage.delete(key: _legacyPasswordKey);
    } catch (_) {
      // Cleanup legacy credential bersifat best-effort.
    }
  }

  static Future<void> saveLoginPreference({
    required bool rememberMe,
    String? email,
  }) async {
    await clearLegacyStoredPassword();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, rememberMe);

    final String normalizedEmail = (email ?? '').trim();
    if (rememberMe && normalizedEmail.isNotEmpty) {
      await prefs.setString(_emailKey, normalizedEmail);
    } else {
      await prefs.remove(_emailKey);
    }
  }

  static Future<bool> hasSeenOnboarding() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingSeenKey) ?? false;
  }

  static Future<void> markOnboardingSeen() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, true);
  }

  static Future<void> clearRememberedLogin() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, false);
    await prefs.remove(_emailKey);
    await clearLegacyStoredPassword();
  }
}
