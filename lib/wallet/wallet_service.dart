import 'package:supabase_flutter/supabase_flutter.dart';

class WalletService {
  WalletService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;


  String get _currentUserId {
    final String? id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Pengguna belum login.');
    return id;
  }

  Future<Map<String, dynamic>> fetchSummary() async {
    final dynamic response = await _client.rpc('get_mitra_wallet_summary');
    Map<String, dynamic> summary;
    if (response is List && response.isNotEmpty && response.first is Map) {
      summary = Map<String, dynamic>.from(response.first as Map);
    } else if (response is Map) {
      summary = Map<String, dynamic>.from(response);
    } else {
      summary = <String, dynamic>{
        'pending_balance': 0,
        'available_balance': 0,
        'held_balance': 0,
        'withdrawn_total': 0,
        'minimum_payout': 10000,
      };
    }

    try {
      final dynamic settingsResponse = await _client.rpc('get_business_settings');
      if (settingsResponse is List &&
          settingsResponse.isNotEmpty &&
          settingsResponse.first is Map) {
        summary.addAll(
          Map<String, dynamic>.from(settingsResponse.first as Map),
        );
      } else if (settingsResponse is Map) {
        summary.addAll(Map<String, dynamic>.from(settingsResponse));
      }
    } catch (_) {
      // Migration economics belum dijalankan; UI tetap dapat memakai default MVP.
      summary['platform_fee_percent'] ??= 6;
    }
    summary['platform_fee_percent'] ??= 6;
    return summary;
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

  Future<List<Map<String, dynamic>>> fetchBankAccounts() async {
    final dynamic response = await _client
        .from('mitra_bank_accounts')
        .select('id, mitra_id, bank_name, account_number, account_holder, is_default, created_at, updated_at')
        .eq('mitra_id', _currentUserId)
        .order('is_default', ascending: false)
        .order('created_at');
    return List<Map<String, dynamic>>.from(response as List);
  }

  Future<void> addBankAccount({
    required String bankName,
    required String accountNumber,
    required String accountHolder,
    bool isDefault = false,
  }) async {
    final bool makeDefault = isDefault || (await fetchBankAccounts()).isEmpty;
    if (makeDefault) {
      await _client
          .from('mitra_bank_accounts')
          .update(<String, dynamic>{'is_default': false})
          .eq('mitra_id', _currentUserId)
          .eq('is_default', true);
    }
    await _client.from('mitra_bank_accounts').insert(<String, dynamic>{
      'mitra_id': _currentUserId,
      'bank_name': bankName.trim(),
      'account_number': accountNumber.trim(),
      'account_holder': accountHolder.trim(),
      'is_default': makeDefault,
    });
  }

  Future<void> updateBankAccount({
    required String accountId,
    required String bankName,
    required String accountNumber,
    required String accountHolder,
    bool makeDefault = false,
  }) async {
    if (makeDefault) {
      await _client.rpc(
        'set_default_mitra_bank_account',
        params: <String, dynamic>{'p_account_id': accountId},
      );
    }
    await _client
        .from('mitra_bank_accounts')
        .update(<String, dynamic>{
          'bank_name': bankName.trim(),
          'account_number': accountNumber.trim(),
          'account_holder': accountHolder.trim(),
        })
        .eq('id', accountId)
        .eq('mitra_id', _currentUserId);
  }

  Future<void> setDefaultBankAccount(String accountId) async {
    await _client.rpc(
      'set_default_mitra_bank_account',
      params: <String, dynamic>{'p_account_id': accountId},
    );
  }

  Future<void> deleteBankAccount(String accountId) async {
    final List<Map<String, dynamic>> accounts = await fetchBankAccounts();
    Map<String, dynamic>? target;
    for (final Map<String, dynamic> row in accounts) {
      if (row['id'].toString() == accountId) {
        target = row;
        break;
      }
    }
    await _client
        .from('mitra_bank_accounts')
        .delete()
        .eq('id', accountId)
        .eq('mitra_id', _currentUserId);

    if (target?['is_default'] == true) {
      final List<Map<String, dynamic>> remaining = await fetchBankAccounts();
      if (remaining.isNotEmpty) {
        await setDefaultBankAccount(remaining.first['id'].toString());
      }
    }
  }

  Future<String> requestPayout({
    required num amount,
    required String bankAccountId,
  }) async {
    final dynamic response = await _client.rpc(
      'request_mitra_payout_v2',
      params: <String, dynamic>{
        'p_amount': amount,
        'p_bank_account_id': bankAccountId,
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
