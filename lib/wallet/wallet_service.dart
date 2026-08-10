import 'package:supabase_flutter/supabase_flutter.dart';

class WalletPinException implements Exception {
  const WalletPinException(
    this.message, {
    this.code,
    this.attemptsRemaining,
    this.lockedUntil,
  });

  final String message;
  final String? code;
  final int? attemptsRemaining;
  final DateTime? lockedUntil;

  @override
  String toString() => message;
}

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
        .select(
          'id, mitra_id, bank_name, account_number, account_holder, is_default, created_at, updated_at',
        )
        .eq('mitra_id', _currentUserId)
        .order('is_default', ascending: false)
        .order('created_at');
    return List<Map<String, dynamic>>.from(response as List);
  }

  Future<Map<String, dynamic>> fetchPinStatus() async {
    final dynamic response = await _client.rpc('get_wallet_pin_status');
    return _asMap(response);
  }

  Future<void> setupPin(String pin) async {
    final dynamic response = await _client.rpc(
      'setup_wallet_pin',
      params: <String, dynamic>{'p_pin': pin},
    );
    _requireOk(response);
  }

  Future<void> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    final dynamic response = await _client.rpc(
      'change_wallet_pin',
      params: <String, dynamic>{
        'p_current_pin': currentPin,
        'p_new_pin': newPin,
      },
    );
    _requireOk(response);
  }

  Future<void> resetPinWithPassword({
    required String password,
    required String newPin,
  }) async {
    final FunctionResponse response = await _client.functions.invoke(
      'reset-wallet-pin',
      body: <String, dynamic>{'password': password, 'new_pin': newPin},
    );
    final dynamic raw = response.data;
    final Map<String, dynamic> data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{'data': raw};
    if (response.status < 200 || response.status >= 300 || data['ok'] != true) {
      throw StateError(
        (data['error'] ?? 'PIN AyoPay belum dapat direset.').toString(),
      );
    }
  }

  Future<void> addBankAccount({
    required String bankName,
    required String accountNumber,
    required String accountHolder,
    required String pin,
    bool isDefault = false,
  }) async {
    final dynamic response = await _client.rpc(
      'secure_add_mitra_bank_account',
      params: <String, dynamic>{
        'p_bank_name': bankName.trim(),
        'p_account_number': accountNumber.trim(),
        'p_account_holder': accountHolder.trim(),
        'p_is_default': isDefault,
        'p_pin': pin,
      },
    );
    _requireOk(response);
  }

  Future<void> updateBankAccount({
    required String accountId,
    required String bankName,
    required String accountNumber,
    required String accountHolder,
    required String pin,
    bool makeDefault = false,
  }) async {
    final dynamic response = await _client.rpc(
      'secure_update_mitra_bank_account',
      params: <String, dynamic>{
        'p_account_id': accountId,
        'p_bank_name': bankName.trim(),
        'p_account_number': accountNumber.trim(),
        'p_account_holder': accountHolder.trim(),
        'p_make_default': makeDefault,
        'p_pin': pin,
      },
    );
    _requireOk(response);
  }

  Future<void> setDefaultBankAccount(String accountId, {required String pin}) async {
    final dynamic response = await _client.rpc(
      'secure_set_default_mitra_bank_account',
      params: <String, dynamic>{'p_account_id': accountId, 'p_pin': pin},
    );
    _requireOk(response);
  }

  Future<void> deleteBankAccount(String accountId, {required String pin}) async {
    final dynamic response = await _client.rpc(
      'secure_delete_mitra_bank_account',
      params: <String, dynamic>{'p_account_id': accountId, 'p_pin': pin},
    );
    _requireOk(response);
  }

  Future<String> requestPayout({
    required num amount,
    required String bankAccountId,
    required String pin,
  }) async {
    final dynamic response = await _client.rpc(
      'secure_request_mitra_payout',
      params: <String, dynamic>{
        'p_amount': amount,
        'p_bank_account_id': bankAccountId,
        'p_pin': pin,
      },
    );
    final Map<String, dynamic> data = _requireOk(response);
    return (data['request_id'] ?? '').toString();
  }

  Future<void> cancelPayout(String requestId, {required String pin}) async {
    final dynamic response = await _client.rpc(
      'secure_cancel_mitra_payout',
      params: <String, dynamic>{'p_request_id': requestId, 'p_pin': pin},
    );
    _requireOk(response);
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _requireOk(dynamic raw) {
    final Map<String, dynamic> data = _asMap(raw);
    if (data['ok'] == true) return data;

    final String code = (data['code'] ?? 'wallet_security_error').toString();
    final int? attempts = int.tryParse(
      (data['attempts_remaining'] ?? '').toString(),
    );
    final DateTime? lockedUntil = DateTime.tryParse(
      (data['locked_until'] ?? '').toString(),
    )?.toLocal();

    throw WalletPinException(
      _pinErrorMessage(code, attempts, lockedUntil),
      code: code,
      attemptsRemaining: attempts,
      lockedUntil: lockedUntil,
    );
  }

  String _pinErrorMessage(
    String code,
    int? attemptsRemaining,
    DateTime? lockedUntil,
  ) {
    switch (code) {
      case 'pin_not_set':
        return 'Buat PIN AyoPay terlebih dahulu.';
      case 'invalid_pin':
        return attemptsRemaining == null
            ? 'PIN AyoPay salah.'
            : 'PIN AyoPay salah. Sisa $attemptsRemaining percobaan.';
      case 'pin_locked':
        if (lockedUntil == null) {
          return 'PIN AyoPay dikunci sementara karena terlalu banyak percobaan.';
        }
        final String hour = lockedUntil.hour.toString().padLeft(2, '0');
        final String minute = lockedUntil.minute.toString().padLeft(2, '0');
        return 'PIN AyoPay dikunci sementara sampai $hour:$minute.';
      case 'invalid_format':
        return 'PIN AyoPay harus terdiri dari tepat 6 angka.';
      case 'weak_pin':
        return 'PIN terlalu mudah ditebak. Gunakan kombinasi 6 angka yang lebih unik.';
      case 'pin_already_set':
        return 'PIN AyoPay sudah aktif. Gunakan menu Ubah PIN.';
      case 'pin_unchanged':
        return 'PIN baru harus berbeda dari PIN lama.';
      case 'invalid_bank':
        return 'Data rekening belum lengkap.';
      case 'bank_not_found':
        return 'Rekening pencairan tidak ditemukan.';
      default:
        return 'Keamanan AyoPay belum dapat memproses tindakan ini.';
    }
  }
}
