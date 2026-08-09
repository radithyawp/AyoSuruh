import 'package:supabase_flutter/supabase_flutter.dart';

class AccountService {
  AccountService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>> fetchDeletionReadiness() async {
    final dynamic raw = await _client.rpc('get_account_deletion_readiness');
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw StateError('Status kesiapan akun belum dapat dibaca.');
  }

  Future<void> deactivateAccount({
    String? reasonCode,
    String? reasonLabel,
    String? note,
  }) async {
    await _client.rpc(
      'deactivate_my_account',
      params: <String, dynamic>{
        'p_reason_code': _nullable(reasonCode),
        'p_reason_label': _nullable(reasonLabel),
        'p_note': _nullable(note),
      },
    );
  }

  Future<void> deleteAccount({
    required String confirmation,
    String? reasonCode,
    String? reasonLabel,
    String? note,
  }) async {
    final FunctionResponse response = await _client.functions.invoke(
      'delete-user-account',
      body: <String, dynamic>{
        'confirmation': confirmation,
        'reason_code': _nullable(reasonCode),
        'reason_label': _nullable(reasonLabel),
        'note': _nullable(note),
      },
    );

    final dynamic raw = response.data;
    final Map<String, dynamic> data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{'data': raw};

    if (response.status < 200 || response.status >= 300) {
      throw StateError(
        (data['error'] ?? data['message'] ?? 'Akun belum dapat dihapus.')
            .toString(),
      );
    }
    if (data['success'] != true) {
      throw StateError(
        (data['error'] ?? 'Akun belum dapat dihapus.').toString(),
      );
    }
  }

  String? _nullable(String? value) {
    final String text = (value ?? '').trim();
    return text.isEmpty ? null : text;
  }
}
