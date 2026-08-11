import 'package:supabase_flutter/supabase_flutter.dart';

class AyoPayException implements Exception {
  const AyoPayException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class AyoPayService {
  AyoPayService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>> fetchSummary() async {
    final dynamic response = await _client.rpc('get_my_ayopay_summary');
    return _asMap(response);
  }

  Future<List<Map<String, dynamic>>> fetchLedger({int limit = 30}) async {
    final dynamic response = await _client.rpc(
      'get_my_ayopay_ledger',
      params: <String, dynamic>{'p_limit': limit},
    );
    if (response is! List) return <Map<String, dynamic>>[];
    return response
        .whereType<Map>()
        .map((Map row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<Map<String, dynamic>> activate() async {
    final dynamic response = await _client.rpc('activate_ayopay');
    final Map<String, dynamic> data = _asMap(response);
    if (data['ok'] == true) return data;

    final String code = (data['code'] ?? 'activation_failed').toString();
    throw AyoPayException(_messageForCode(code), code: code);
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    return <String, dynamic>{};
  }

  String _messageForCode(String code) {
    switch (code) {
      case 'pin_required':
        return 'Buat PIN AyoPay terlebih dahulu untuk mengaktifkan AyoPay.';
      case 'suspended':
        return 'AyoPay sedang dibatasi. Hubungi dukungan Ayo Suruh.';
      case 'already_active':
        return 'AyoPay sudah aktif.';
      default:
        return 'AyoPay belum dapat diaktifkan. Coba lagi.';
    }
  }
}
