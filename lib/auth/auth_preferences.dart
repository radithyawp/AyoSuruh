import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthPreferences {
  AuthPreferences._();

  static const String _rememberKey = 'auth_remember_me';
  static const String _emailKey = 'auth_remembered_email';
  static const String _passwordKey = 'auth_remembered_password';
  static const String _onboardingSeenKey = 'auth_onboarding_seen_v1';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Default `true` menjaga perilaku aplikasi sebelum fitur Remember Me
  /// ditambahkan: sesi Supabase yang masih valid tetap dipulihkan saat app dibuka.
  static Future<bool> shouldRememberSession() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberKey) ?? true;
  }

  static Future<String?> rememberedEmail() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? value = prefs.getString(_emailKey)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static Future<String?> rememberedPassword() async {
    final String? value = await _secureStorage.read(key: _passwordKey);
    final String normalized = (value ?? '').trim();
    return normalized.isEmpty ? null : value;
  }

  static Future<void> saveLoginPreference({
    required bool rememberMe,
    String? email,
    String? password,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, rememberMe);

    final String normalizedEmail = (email ?? '').trim();
    if (rememberMe && normalizedEmail.isNotEmpty) {
      await prefs.setString(_emailKey, normalizedEmail);
    } else {
      await prefs.remove(_emailKey);
    }

    if (!rememberMe) {
      await _secureStorage.delete(key: _passwordKey);
    } else if (password != null) {
      if (password.isNotEmpty) {
        // Password tidak pernah disimpan di SharedPreferences/plaintext.
        // flutter_secure_storage memakai Android Keystore / iOS Keychain.
        await _secureStorage.write(key: _passwordKey, value: password);
      } else {
        await _secureStorage.delete(key: _passwordKey);
      }
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
    await _secureStorage.delete(key: _passwordKey);
  }
}
