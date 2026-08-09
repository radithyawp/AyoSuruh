import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();

  static final SupabaseClient _supabase = Supabase.instance.client;

  static const String mobileRedirectUrl =
      'io.supabase.ayosuruh://login-callback/';
  static const String passwordRecoveryRedirectUrl =
      'io.supabase.ayosuruh://reset-password/';

  static Future<bool> signInWithGoogle() {
    return _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? Uri.base.origin : mobileRedirectUrl,
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
      queryParams: const <String, String>{'prompt': 'select_account'},
    );
  }

  static Future<void> sendPasswordResetEmail(String email) {
    final String redirectTo = kIsWeb
        ? '${Uri.base.origin}/reset-password'
        : passwordRecoveryRedirectUrl;
    debugPrint('PASSWORD RESET REDIRECT => $redirectTo');

    return _supabase.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: redirectTo,
    );
  }

  static Future<bool> reactivateCurrentAccountIfNeeded() async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      final Map<String, dynamic>? row = await _supabase
          .from('users')
          .select('account_state')
          .eq('id', user.id)
          .maybeSingle();
      final String state = (row?['account_state'] ?? 'active')
          .toString()
          .toLowerCase();
      if (state == 'deleted') {
        throw StateError('Akun ini sudah dihapus.');
      }
      if (state != 'deactivated') return false;

      final dynamic reactivated = await _supabase.rpc('reactivate_my_account');
      return reactivated == true;
    } catch (error) {
      final String message = error.toString().toLowerCase();
      final bool migrationMissing =
          message.contains('account_state') ||
          message.contains('reactivate_my_account') ||
          message.contains('does not exist');
      if (migrationMissing) {
        debugPrint('Account lifecycle migration belum tersedia: $error');
        return false;
      }
      rethrow;
    }
  }

  static Future<void> syncCurrentUserProfile() async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.rpc('sync_current_user_profile');
      return;
    } catch (error) {
      debugPrint('RPC sync_current_user_profile belum tersedia: $error');
    }

    final Map<String, dynamic> metadata = Map<String, dynamic>.from(
      user.userMetadata ?? const {},
    );

    String firstNonEmpty(Iterable<dynamic> values) {
      for (final dynamic value in values) {
        final String text = value?.toString().trim() ?? '';
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    final String email = user.email?.trim() ?? '';
    final String fallbackName = email.contains('@')
        ? email.split('@').first
        : 'Pengguna Ayo Suruh';
    final String fullName = firstNonEmpty(<dynamic>[
      metadata['fullname'],
      metadata['full_name'],
      metadata['name'],
      fallbackName,
    ]);
    final String phone = firstNonEmpty(<dynamic>[
      user.phone,
      metadata['phone'],
      metadata['phone_number'],
    ]);
    final String avatarUrl = firstNonEmpty(<dynamic>[
      metadata['avatar_url'],
      metadata['picture'],
    ]);

    final Map<String, dynamic> profile = <String, dynamic>{
      'id': user.id,
      'email': email,
      'fullname': fullName,
    };
    if (phone.isNotEmpty) profile['phone'] = phone;
    if (avatarUrl.isNotEmpty) profile['avatar_url'] = avatarUrl;

    try {
      await _supabase.from('users').upsert(profile, onConflict: 'id');
    } catch (error) {
      debugPrint('Fallback sinkronisasi public.users gagal: $error');
      rethrow;
    }
  }
}
