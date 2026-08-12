import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class PhoneConfirmationService {
  static const MethodChannel _channel = MethodChannel(
    'com.ayosuruh.app/phone_hint',
  );

  static const String unverified = 'unverified';
  static const String deviceConfirmed = 'device_confirmed';
  static const String verified = 'verified';

  static bool get supportsDeviceHint =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool isConfirmed(String? level) {
    final String value = (level ?? '').trim().toLowerCase();
    return value == deviceConfirmed || value == verified;
  }

  static String normalizeIndonesiaPhone(String raw) {
    String value = raw.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    if (value.isEmpty) return '';

    if (value.startsWith('+')) {
      value = '+${value.substring(1).replaceAll(RegExp(r'[^0-9]'), '')}';
    } else {
      value = value.replaceAll(RegExp(r'[^0-9]'), '');
    }

    if (value.startsWith('+62')) return value;
    // Nomor internasional non-Indonesia jangan dipaksa menjadi +62; validasi
    // di bawah akan menolaknya untuk scope Ayo Suruh saat ini.
    if (value.startsWith('+')) return value;
    if (value.startsWith('62')) return '+$value';
    if (value.startsWith('0')) return '+62${value.substring(1)}';

    // Ayo Suruh masih beroperasi pada scope Indonesia. Nomor lokal yang
    // dikembalikan tanpa awalan 0 diperlakukan sebagai nomor Indonesia.
    return '+62$value';
  }

  static String nationalDigits(String raw) {
    final String normalized = normalizeIndonesiaPhone(raw);
    if (normalized.startsWith('+62')) return normalized.substring(3);
    return normalized.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static bool isValidIndonesiaPhone(String raw) {
    final String normalized = normalizeIndonesiaPhone(raw);
    return RegExp(r'^\+628[0-9]{7,12}$').hasMatch(normalized);
  }

  static String mask(String raw) {
    final String normalized = normalizeIndonesiaPhone(raw);
    final String digits = normalized.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length <= 7) return normalized;
    final String start = digits.substring(0, 4);
    final String end = digits.substring(digits.length - 4);
    return '+$start••••$end';
  }

  static Future<String?> requestPhoneNumberHint() async {
    if (!supportsDeviceHint) return null;
    try {
      final String? phone = await _channel.invokeMethod<String>(
        'requestPhoneNumberHint',
      );
      final String normalized = normalizeIndonesiaPhone(phone ?? '');
      return normalized.isEmpty ? null : normalized;
    } on PlatformException catch (error) {
      debugPrint(
        'Phone Number Hint unavailable: ${error.code} ${error.message}',
      );
      rethrow;
    }
  }

  static Future<void> saveCurrentUserPhone({
    required String phone,
    required String verificationLevel,
  }) async {
    final SupabaseClient supabase = Supabase.instance.client;
    final User? user = supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Sesi telah berakhir. Silakan masuk kembali.');
    }

    final String normalized = normalizeIndonesiaPhone(phone);
    if (!isValidIndonesiaPhone(normalized)) {
      throw FormatException('Nomor HP belum valid.');
    }

    final String level = switch (verificationLevel.trim().toLowerCase()) {
      verified => verified,
      deviceConfirmed => deviceConfirmed,
      _ => unverified,
    };
    final String method = switch (level) {
      verified => 'sms_or_carrier',
      deviceConfirmed => 'phone_number_hint',
      _ => 'manual',
    };
    final String? confirmedAt = level == unverified
        ? null
        : DateTime.now().toUtc().toIso8601String();

    await supabase.from('users').update(<String, dynamic>{
      'phone': normalized,
      'phone_verification_level': level,
      'phone_confirmation_method': method,
      'phone_confirmed_at': confirmedAt,
    }).eq('id', user.id);

    final Map<String, dynamic> metadata = Map<String, dynamic>.from(
      user.userMetadata ?? const <String, dynamic>{},
    );
    metadata.addAll(<String, dynamic>{
      'phone': normalized,
      'phone_verification_level': level,
      'phone_confirmation_method': method,
    });

    await supabase.auth.updateUser(UserAttributes(data: metadata));
  }
}
