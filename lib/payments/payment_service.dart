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
            id, job_id, amount, service_fee, platform_fee_percent,
            base_platform_fee_percent, platform_fee_amount, mitra_net_amount,
            first_job_bonus_applied, first_job_bonus_amount,
            status, paid_at, created_at,
            updated_at, provider, payment_required, order_id, snap_token,
            redirect_url, transaction_id, transaction_status, fraud_status,
            payment_type, status_code, status_message, expires_at,
            refunded_amount, refund_status, refunded_at,
            user_voucher_id, voucher_code, discount_amount, payable_amount,
            payment_method_selected_at, cash_confirmed_at, cash_confirmed_by
          ''')
          .eq('job_id', jobId)
          .maybeSingle();
    } on PostgrestException catch (error) {
      debugPrint(
        'Kolom payment terbaru belum tersedia. Menggunakan skema dasar: $error',
      );
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
        'discount_amount': 0,
      };
    }
  }

  Future<Map<String, dynamic>> fetchJobContext(String jobId) async {
    return await _client
        .from('jobs')
        .select('id, customer_id, mitra_id, status, progress_stage')
        .eq('id', jobId)
        .single();
  }

  Stream<Map<String, dynamic>?> watchJobPayment(String jobId) {
    return _client
        .from('payments')
        .stream(primaryKey: <String>['id'])
        .eq('job_id', jobId)
        .map((List<Map<String, dynamic>> rows) {
          if (rows.isEmpty) return null;
          return Map<String, dynamic>.from(rows.first);
        });
  }

  Future<List<Map<String, dynamic>>> fetchJobPaymentAttempts(
    String jobId,
  ) async {
    try {
      final dynamic response = await _client.rpc(
        'get_job_payment_attempts',
        params: <String, dynamic>{'p_job_id': jobId},
      );
      if (response is! List) return <Map<String, dynamic>>[];
      return response
          .whereType<Map>()
          .map((Map row) => Map<String, dynamic>.from(row))
          .toList();
    } on PostgrestException catch (error) {
      final String message = error.message.toLowerCase();
      final bool functionMissing =
          message.contains('get_job_payment_attempts') &&
              (message.contains('not find') ||
                  message.contains('does not exist') ||
                  error.code == 'PGRST202');
      if (!functionMissing) rethrow;
      debugPrint('Migration payment stage 2 belum dijalankan: $error');
      return <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> fetchMyPaymentHistory() async {
    final dynamic response = await _client.rpc('get_my_payment_history');
    if (response is! List) return <Map<String, dynamic>>[];
    return response
        .whereType<Map>()
        .map((Map row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<Map<String, dynamic>> prepareCashPayment({
    required String jobId,
    String? userVoucherId,
  }) async {
    final dynamic response = await _client.rpc(
      'prepare_cash_payment',
      params: <String, dynamic>{
        'p_job_id': jobId,
        'p_user_voucher_id': userVoucherId,
      },
    );
    return _parseRpcPayment(
      response,
      'Pembayaran tunai belum dapat disiapkan.',
    );
  }

  Future<Map<String, dynamic>> confirmCashPayment(String jobId) async {
    final dynamic response = await _client.rpc(
      'confirm_cash_payment',
      params: <String, dynamic>{'p_job_id': jobId},
    );
    return _parseRpcPayment(
      response,
      'Pembayaran tunai belum dapat dikonfirmasi.',
    );
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

  Future<Map<String, dynamic>> createSandboxQrisTransaction(
    String jobId,
  ) async {
    final FunctionResponse response = await _client.functions.invoke(
      'create-midtrans-snap',
      body: <String, dynamic>{
        'job_id': jobId,
        'sandbox_qris': true,
      },
    );
    return _parseFunctionResponse(
      response,
      'QRIS Sandbox belum dapat dibuat.',
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

  Map<String, dynamic> _parseRpcPayment(dynamic response, String fallback) {
    if (response is List && response.isNotEmpty && response.first is Map) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    if (response is Map) return Map<String, dynamic>.from(response);
    throw StateError(fallback);
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
