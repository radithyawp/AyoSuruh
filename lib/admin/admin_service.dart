import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  AdminService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<bool> isCurrentUserAdmin() async {
    if (_client.auth.currentUser == null) return false;
    try {
      final dynamic response = await _client.rpc('is_current_user_admin');
      return response == true;
    } on PostgrestException catch (error) {
      final String message = error.message.toLowerCase();
      if (error.code == 'PGRST202' || message.contains('is_current_user_admin')) {
        return false;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchDashboardSummary() async {
    final dynamic response = await _client.rpc('admin_dashboard_summary');
    if (response is List && response.isNotEmpty && response.first is Map) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    if (response is Map) return Map<String, dynamic>.from(response);
    return <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    final dynamic response = await _client.rpc('admin_list_users');
    if (response is! List) return <Map<String, dynamic>>[];
    return response
        .whereType<Map>()
        .map((Map row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchMitraApplications() async {
    final dynamic response = await _client.rpc('admin_list_mitra_applications');
    if (response is! List) return <Map<String, dynamic>>[];
    return response
        .whereType<Map>()
        .map((Map row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchPayouts() async {
    final dynamic response = await _client.rpc('admin_list_payouts');
    if (response is! List) return <Map<String, dynamic>>[];
    return response
        .whereType<Map>()
        .map((Map row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> reviewMitraApplication({
    required String applicationId,
    required String action,
    String? note,
  }) async {
    await _client.rpc(
      'admin_review_mitra_application',
      params: <String, dynamic>{
        'p_application_id': applicationId,
        'p_action': action,
        'p_note': note,
      },
    );
  }

  Future<void> processPayout({
    required String payoutId,
    required String action,
    String? note,
  }) async {
    await _client.rpc(
      'admin_process_payout',
      params: <String, dynamic>{
        'p_request_id': payoutId,
        'p_action': action,
        'p_note': note,
      },
    );
  }

  Future<String> createSignedMitraDocumentUrl(String storagePath) async {
    final String path = storagePath.trim();
    if (path.isEmpty) throw ArgumentError('Path dokumen kosong.');
    return _client.storage
        .from('mitra-documents')
        .createSignedUrl(path, 600);
  }

  Future<Map<String, dynamic>> fetchMyProfile() async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Admin belum login.');
    final Map<String, dynamic>? row = await _client
        .from('users')
        .select('id, fullname, email, phone, avatar_url')
        .eq('id', userId)
        .maybeSingle();
    return Map<String, dynamic>.from(row ?? <String, dynamic>{});
  }
}
