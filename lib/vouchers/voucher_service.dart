import 'package:supabase_flutter/supabase_flutter.dart';

class VoucherService {
  VoucherService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchMyVouchers() async {
    final dynamic response = await _client.rpc('get_my_vouchers');
    if (response is! List) return <Map<String, dynamic>>[];
    return response
        .whereType<Map>()
        .map((Map row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<Map<String, dynamic>> preview({
    required String userVoucherId,
    required num subtotal,
    String? jobId,
  }) async {
    final dynamic response = await _client.rpc(
      'preview_my_voucher',
      params: <String, dynamic>{
        'p_user_voucher_id': userVoucherId,
        'p_subtotal': subtotal,
        'p_job_id': jobId,
      },
    );
    if (response is Map) return Map<String, dynamic>.from(response);
    return <String, dynamic>{};
  }
}
