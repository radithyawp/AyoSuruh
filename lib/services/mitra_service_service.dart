import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MitraServiceService {
  MitraServiceService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _currentUserId {
    final String? id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Pengguna belum login.');
    return id;
  }

  Future<List<Map<String, dynamic>>> fetchPublicServices() async {
    try {
      final dynamic result = await _client
          .from('mitra_services')
          .select('''
            id, mitra_id, category_id, title, description, starting_price,
            is_active, created_at, updated_at,
            categories(id, name, icon),
            mitra:users!mitra_services_mitra_id_fkey(id, fullname, avatar_url)
          ''')
          .eq('is_active', true)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(result as List);
    } on PostgrestException catch (error) {
      if (error.message.toLowerCase().contains('mitra_services')) {
        debugPrint('Migration marketplace jasa mitra belum tersedia: $error');
        return <Map<String, dynamic>>[];
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchMyServices() async {
    try {
      final dynamic result = await _client
          .from('mitra_services')
          .select('''
            id, mitra_id, category_id, title, description, starting_price,
            is_active, created_at, updated_at,
            categories(id, name, icon)
          ''')
          .eq('mitra_id', _currentUserId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(result as List);
    } on PostgrestException catch (error) {
      if (error.message.toLowerCase().contains('mitra_services')) {
        debugPrint('Migration marketplace jasa mitra belum tersedia: $error');
        return <Map<String, dynamic>>[];
      }
      rethrow;
    }
  }

  Future<void> createService({
    required String categoryId,
    required String title,
    required String description,
    required num startingPrice,
  }) async {
    await _client.from('mitra_services').insert(<String, dynamic>{
      'mitra_id': _currentUserId,
      'category_id': categoryId,
      'title': title.trim(),
      'description': description.trim(),
      'starting_price': startingPrice,
      'is_active': true,
    });
  }

  Future<void> updateService({
    required String serviceId,
    required String categoryId,
    required String title,
    required String description,
    required num startingPrice,
  }) async {
    await _client
        .from('mitra_services')
        .update(<String, dynamic>{
          'category_id': categoryId,
          'title': title.trim(),
          'description': description.trim(),
          'starting_price': startingPrice,
        })
        .eq('id', serviceId)
        .eq('mitra_id', _currentUserId);
  }

  Future<void> setActive(String serviceId, bool isActive) async {
    await _client
        .from('mitra_services')
        .update(<String, dynamic>{'is_active': isActive})
        .eq('id', serviceId)
        .eq('mitra_id', _currentUserId);
  }

  Future<void> deleteService(String serviceId) async {
    await _client
        .from('mitra_services')
        .delete()
        .eq('id', serviceId)
        .eq('mitra_id', _currentUserId);
  }
}
