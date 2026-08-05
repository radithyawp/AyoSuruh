import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentService {
  PaymentService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> fetchJobPayment(String jobId) async {
    try {
      final dynamic response = await _client.rpc(
        'get_job_payment',
        params: <String, dynamic>{'p_job_id': jobId},
      );

      if (response is List && response.isNotEmpty && response.first is Map) {
        return Map<String, dynamic>.from(response.first as Map);
      }
      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
      return null;
    } on PostgrestException catch (error) {
      final String message = error.message.toLowerCase();
      final bool functionMissing = message.contains('get_job_payment') &&
          (message.contains('not find') ||
              message.contains('does not exist') ||
              error.code == 'PGRST202');
      if (!functionMissing) rethrow;
      debugPrint(
        'RPC get_job_payment belum tersedia. Menggunakan fallback RLS: $error',
      );
    }

    try {
      return await _client
          .from('payments')
          .select('''
            id, job_id, amount, service_fee, status, paid_at, created_at,
            updated_at, provider, payment_required, order_id, snap_token,
            redirect_url, transaction_id, transaction_status, fraud_status,
            payment_type, status_code, status_message, expires_at
          ''')
          .eq('job_id', jobId)
          .maybeSingle();
    } on PostgrestException catch (error) {
      debugPrint('Kolom Midtrans belum tersedia. Menggunakan skema dasar: $error');
      final Map<String, dynamic>? legacy = await _client
          .from('payments')
          .select('id, job_id, amount, service_fee, status, paid_at, created_at')
          .eq('job_id', jobId)
          .maybeSingle();
      if (legacy == null) return null;
      return <String, dynamic>{
        ...legacy,
        'provider': 'midtrans',
        'payment_required': false,
      };
    }
  }

  Future<Map<String, dynamic>> createSnapTransaction(String jobId) async {
    final FunctionResponse response = await _client.functions.invoke(
      'create-midtrans-snap',
      body: <String, dynamic>{'job_id': jobId},
    );
    return _parseFunctionResponse(
      response,
      'Transaksi Midtrans belum dapat dibuat.',
    );
  }

  Future<Map<String, dynamic>> refreshPaymentStatus(String jobId) async {
    final FunctionResponse response = await _client.functions.invoke(
      'refresh-midtrans-status',
      body: <String, dynamic>{'job_id': jobId},
    );
    return _parseFunctionResponse(
      response,
      'Status pembayaran belum dapat diperbarui.',
    );
  }

  Map<String, dynamic> _parseFunctionResponse(
    FunctionResponse response,
    String fallbackMessage,
  ) {
    final dynamic raw = response.data;
    final Map<String, dynamic> data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{'data': raw};

    if (response.status < 200 || response.status >= 300) {
      final String message =
          (data['message'] ?? data['error'] ?? fallbackMessage).toString();
      throw StateError(message);
    }

    if (data['error'] != null && data['success'] != true) {
      throw StateError(data['error'].toString());
    }
    return data;
  }
}
