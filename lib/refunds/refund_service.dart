import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RefundService {
  RefundService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> fetchJobRefund(String jobId) async {
    try {
      final dynamic response = await _client.rpc(
        'get_job_refund',
        params: <String, dynamic>{'p_job_id': jobId},
      );
      if (response is List && response.isNotEmpty && response.first is Map) {
        return Map<String, dynamic>.from(response.first as Map);
      }
      if (response is Map) return Map<String, dynamic>.from(response);
      return null;
    } on PostgrestException catch (error) {
      final String message = error.message.toLowerCase();
      final bool missing = message.contains('get_job_refund') &&
          (message.contains('not find') ||
              message.contains('does not exist') ||
              error.code == 'PGRST202');
      if (!missing) rethrow;
      debugPrint('Migration refund belum dijalankan: $error');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchMyRefundHistory() async {
    final dynamic response = await _client.rpc('get_my_refund_history');
    if (response is! List) return <Map<String, dynamic>>[];
    return response
        .whereType<Map>()
        .map((Map row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<Map<String, dynamic>> requestRefund({
    required String jobId,
    required String reason,
  }) async {
    final FunctionResponse response = await _client.functions.invoke(
      'request-midtrans-refund',
      body: <String, dynamic>{
        'job_id': jobId,
        'reason': reason.trim(),
      },
    );

    final dynamic raw = response.data;
    final Map<String, dynamic> data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{'data': raw};

    if (response.status < 200 || response.status >= 300) {
      throw StateError(
        (data['message'] ?? data['error'] ?? 'Refund belum dapat diproses.')
            .toString(),
      );
    }
    if (data['error'] != null && data['success'] != true) {
      throw StateError(data['error'].toString());
    }
    return data;
  }
}
