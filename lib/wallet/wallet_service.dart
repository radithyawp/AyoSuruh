import 'package:supabase_flutter/supabase_flutter.dart';

class WalletService {
  WalletService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>> fetchSummary() async {
    final dynamic response = await _client.rpc('get_mitra_wallet_summary');
    if (response is List && response.isNotEmpty && response.first is Map) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    if (response is Map) return Map<String, dynamic>.from(response);
    return <String, dynamic>{
      'pending_balance': 0,
      'available_balance': 0,
      'held_balance': 0,
      'withdrawn_total': 0,
      'minimum_payout': 10000,
    };
  }

  Future<List<Map<String, dynamic>>> fetchLedger({int limit = 50}) async {
    final dynamic response = await _client.rpc(
      'get_my_wallet_ledger',
      params: <String, dynamic>{'p_limit': limit},
    );
    if (response is! List) return <Map<String, dynamic>>[];
    return response
        .whereType<Map>()
        .map((Map row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchPayouts() async {
    final dynamic response = await _client.rpc('get_my_payout_requests');
    if (response is! List) return <Map<String, dynamic>>[];
    return response
        .whereType<Map>()
        .map((Map row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<String> requestPayout({
    required num amount,
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  }) async {
    final dynamic response = await _client.rpc(
      'request_mitra_payout',
      params: <String, dynamic>{
        'p_amount': amount,
        'p_bank_name': bankName.trim(),
        'p_account_number': accountNumber.trim(),
        'p_account_holder': accountHolder.trim(),
      },
    );
    return response.toString();
  }

  Future<void> cancelPayout(String requestId) async {
    await _client.rpc(
      'cancel_mitra_payout',
      params: <String, dynamic>{'p_request_id': requestId},
    );
  }
}
