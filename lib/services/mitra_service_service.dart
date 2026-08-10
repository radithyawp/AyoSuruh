import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
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
      final dynamic response = await _client.rpc('get_public_mitra_services');
      if (response is List) {
        final List<Map<String, dynamic>> rows = response
            .whereType<Map>()
            .map((Map raw) {
              final Map<String, dynamic> row = Map<String, dynamic>.from(raw);
              return <String, dynamic>{
                'id': row['id'],
                'mitra_id': row['mitra_id'],
                'category_id': row['category_id'],
                'title': row['title'],
                'description': row['description'],
                'starting_price': row['starting_price'],
                'tags': row['tags'] ?? <String>[],
                'is_bookmarked': row['is_bookmarked'] == true,
                'is_active': true,
                'created_at': row['created_at'],
                'categories': <String, dynamic>{
                  'id': row['category_id'],
                  'name': row['category_name'],
                  'icon': row['category_icon'],
                },
                'mitra': <String, dynamic>{
                  'id': row['mitra_id'],
                  'fullname': row['mitra_fullname'],
                  'avatar_url': row['mitra_avatar_url'],
                  'rating': row['mitra_rating'],
                  'location': row['mitra_location'],
                },
              };
            })
            .toList();
        return _attachImages(rows);
      }
      return <Map<String, dynamic>>[];
    } on PostgrestException catch (error) {
      final String lower = error.message.toLowerCase();
      final bool rpcMissing =
          error.code == 'PGRST202' || lower.contains('get_public_mitra_services');
      if (!rpcMissing) rethrow;

      // Fallback untuk project yang migration Batch 1.1-nya belum dijalankan.
      try {
        final dynamic result = await _client
            .from('mitra_services')
            .select('''
              id, mitra_id, category_id, title, description, starting_price,
              tags, is_active, created_at, updated_at,
              categories(id, name, icon),
              mitra:users!mitra_services_mitra_id_fkey(id, fullname, avatar_url)
            ''')
            .eq('is_active', true)
            .order('created_at', ascending: false);
        return _attachImages(List<Map<String, dynamic>>.from(result as List));
      } on PostgrestException catch (fallbackError) {
        if (fallbackError.message.toLowerCase().contains('mitra_services')) {
          debugPrint(
            'Migration marketplace jasa mitra belum tersedia: $fallbackError',
          );
          return <Map<String, dynamic>>[];
        }
        rethrow;
      }
    }
  }

  Future<List<Map<String, dynamic>>> fetchMyServices() async {
    try {
      final dynamic result = await _client
          .from('mitra_services')
          .select('''
            id, mitra_id, category_id, title, description, starting_price,
            tags, is_active, created_at, updated_at,
            categories(id, name, icon)
          ''')
          .eq('mitra_id', _currentUserId)
          .order('created_at', ascending: false);
      return _attachImages(List<Map<String, dynamic>>.from(result as List));
    } on PostgrestException catch (error) {
      if (error.message.toLowerCase().contains('mitra_services')) {
        debugPrint('Migration marketplace jasa mitra belum tersedia: $error');
        return <Map<String, dynamic>>[];
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchServiceImages(String serviceId) async {
    try {
      final dynamic result = await _client
          .from('mitra_service_images')
          .select('id, service_id, storage_path, sort_order, is_cover, created_at')
          .eq('service_id', serviceId)
          .order('sort_order');
      return List<Map<String, dynamic>>.from(result as List).map((row) {
        final Map<String, dynamic> image = Map<String, dynamic>.from(row);
        final String path = (image['storage_path'] ?? '').toString();
        image['image_url'] = path.isEmpty
            ? null
            : _client.storage.from('mitra-service-images').getPublicUrl(path);
        return image;
      }).toList();
    } on PostgrestException catch (error) {
      if (error.message.toLowerCase().contains('mitra_service_images')) {
        debugPrint('Migration gambar jasa Mitra belum tersedia: $error');
        return <Map<String, dynamic>>[];
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _attachImages(
    List<Map<String, dynamic>> services,
  ) async {
    if (services.isEmpty) return services;
    await Future.wait<void>(
      services.map((Map<String, dynamic> service) async {
        final String serviceId = (service['id'] ?? '').toString();
        if (serviceId.isEmpty) {
          service['service_images'] = <Map<String, dynamic>>[];
          return;
        }
        service['service_images'] = await fetchServiceImages(serviceId);
      }),
    );
    return services;
  }

  Future<String> createService({
    required String categoryId,
    required String title,
    required String description,
    required num startingPrice,
    List<String> tags = const <String>[],
  }) async {
    final Map<String, dynamic> inserted = await _client
        .from('mitra_services')
        .insert(<String, dynamic>{
          'mitra_id': _currentUserId,
          'category_id': categoryId,
          'title': title.trim(),
          'description': description.trim(),
          'starting_price': startingPrice,
          'tags': _normalizeTags(tags),
          'is_active': true,
        })
        .select('id')
        .single();
    return inserted['id'].toString();
  }

  Future<void> updateService({
    required String serviceId,
    required String categoryId,
    required String title,
    required String description,
    required num startingPrice,
    List<String> tags = const <String>[],
  }) async {
    await _client
        .from('mitra_services')
        .update(<String, dynamic>{
          'category_id': categoryId,
          'title': title.trim(),
          'description': description.trim(),
          'starting_price': startingPrice,
          'tags': _normalizeTags(tags),
        })
        .eq('id', serviceId)
        .eq('mitra_id', _currentUserId);
  }

  Future<void> uploadServiceImages({
    required String serviceId,
    required List<XFile> images,
    int startingOrder = 0,
  }) async {
    if (images.isEmpty) return;
    if (startingOrder + images.length > 5) {
      throw ArgumentError('Maksimal 5 foto katalog untuk satu jasa.');
    }

    final List<String> uploadedPaths = <String>[];
    try {
      for (int i = 0; i < images.length; i++) {
        final XFile file = images[i];
        final Uint8List bytes = await file.readAsBytes();
        if (bytes.lengthInBytes > 5 * 1024 * 1024) {
          throw StateError('Ukuran setiap foto katalog maksimal 5 MB.');
        }
        final String extension = _safeImageExtension(file.name);
        final int order = startingOrder + i;
        final String path =
            '$_currentUserId/$serviceId/${DateTime.now().microsecondsSinceEpoch}_$order.$extension';
        await _client.storage.from('mitra-service-images').uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                contentType: _imageMimeType(extension),
                upsert: false,
              ),
            );
        uploadedPaths.add(path);
        await _client.from('mitra_service_images').insert(<String, dynamic>{
          'service_id': serviceId,
          'storage_path': path,
          'sort_order': order,
          'is_cover': order == 0,
        });
      }
      await normalizeServiceCover(serviceId);
    } catch (_) {
      if (uploadedPaths.isNotEmpty) {
        try {
          await _client
              .from('mitra_service_images')
              .delete()
              .inFilter('storage_path', uploadedPaths);
          await _client.storage.from('mitra-service-images').remove(uploadedPaths);
        } catch (cleanupError) {
          debugPrint('Cleanup gambar katalog gagal: $cleanupError');
        }
      }
      rethrow;
    }
  }

  Future<void> deleteServiceImage({
    required String serviceId,
    required String imageId,
    required String storagePath,
  }) async {
    await _client
        .from('mitra_service_images')
        .delete()
        .eq('id', imageId)
        .eq('service_id', serviceId);
    if (storagePath.isNotEmpty) {
      await _client.storage.from('mitra-service-images').remove(<String>[storagePath]);
    }
  }

  Future<void> normalizeServiceCover(String serviceId) async {
    final List<Map<String, dynamic>> images = await fetchServiceImages(serviceId);
    if (images.isEmpty) return;
    final String coverId = images.first['id'].toString();
    await _client
        .from('mitra_service_images')
        .update(<String, dynamic>{'is_cover': false})
        .eq('service_id', serviceId);
    await _client
        .from('mitra_service_images')
        .update(<String, dynamic>{'is_cover': true})
        .eq('id', coverId);
  }

  Future<bool> toggleBookmark({
    required String serviceId,
    required bool currentlyBookmarked,
  }) async {
    if (currentlyBookmarked) {
      await _client
          .from('mitra_service_bookmarks')
          .delete()
          .eq('user_id', _currentUserId)
          .eq('service_id', serviceId);
      return false;
    }

    await _client.from('mitra_service_bookmarks').insert(<String, dynamic>{
      'user_id': _currentUserId,
      'service_id': serviceId,
    });
    return true;
  }

  Future<Map<String, dynamic>?> fetchPublicMitraProfile(String mitraId) async {
    final dynamic result = await _client.rpc(
      'get_public_mitra_profile',
      params: <String, dynamic>{'p_mitra_id': mitraId},
    );
    if (result is List && result.isNotEmpty && result.first is Map) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    if (result is Map && result.isNotEmpty) {
      return Map<String, dynamic>.from(result);
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchPublicMitraReviews(
    String mitraId, {
    int limit = 5,
  }) async {
    final dynamic result = await _client.rpc(
      'get_public_mitra_reviews',
      params: <String, dynamic>{
        'p_mitra_id': mitraId,
        'p_limit': limit,
      },
    );
    if (result is! List) return <Map<String, dynamic>>[];
    return result.whereType<Map>().map((row) {
      return Map<String, dynamic>.from(row);
    }).toList();
  }

  Future<void> setActive(String serviceId, bool isActive) async {
    await _client
        .from('mitra_services')
        .update(<String, dynamic>{'is_active': isActive})
        .eq('id', serviceId)
        .eq('mitra_id', _currentUserId);
  }

  Future<void> deleteService(String serviceId) async {
    final List<Map<String, dynamic>> images = await fetchServiceImages(serviceId);
    final List<String> paths = images
        .map((row) => (row['storage_path'] ?? '').toString())
        .where((String path) => path.isNotEmpty)
        .toList();
    await _client
        .from('mitra_services')
        .delete()
        .eq('id', serviceId)
        .eq('mitra_id', _currentUserId);
    if (paths.isNotEmpty) {
      try {
        await _client.storage.from('mitra-service-images').remove(paths);
      } catch (error) {
        debugPrint('File gambar jasa belum dapat dibersihkan: $error');
      }
    }
  }

  List<String> _normalizeTags(List<String> tags) {
    final List<String> normalized = <String>[];
    final Set<String> seen = <String>{};
    for (final String raw in tags) {
      String tag = raw.trim();
      while (tag.startsWith('#')) {
        tag = tag.substring(1).trim();
      }
      if (tag.isEmpty) continue;
      final String key = tag.toLowerCase();
      if (seen.add(key)) normalized.add(tag.length > 28 ? tag.substring(0, 28) : tag);
      if (normalized.length >= 8) break;
    }
    return normalized;
  }

  String _safeImageExtension(String filename) {
    final String lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.heic')) return 'heic';
    return 'jpg';
  }

  String _imageMimeType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }
}
