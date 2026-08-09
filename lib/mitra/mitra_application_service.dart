import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MitraApplicationService {
  MitraApplicationService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get currentUserId {
    final String? id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Pengguna belum login.');
    }
    return id;
  }

  Future<Map<String, dynamic>> fetchMyProfile() async {
    final Map<String, dynamic>? row = await _client
        .from('users')
        .select('id, email, fullname, phone, alamat, role')
        .eq('id', currentUserId)
        .maybeSingle();

    return Map<String, dynamic>.from(row ?? <String, dynamic>{});
  }


  Future<Map<String, dynamic>?> fetchMitraBaseLocation() async {
    final dynamic result = await _client.rpc('get_my_mitra_base_location');

    if (result is List && result.isNotEmpty && result.first is Map) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    if (result is Map && result.isNotEmpty) {
      return Map<String, dynamic>.from(result);
    }
    return null;
  }

  Future<Map<String, dynamic>> saveMitraBaseLocation({
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    await _client.rpc(
      'save_my_mitra_base_location',
      params: <String, dynamic>{
        'p_address': address.trim(),
        'p_latitude': latitude,
        'p_longitude': longitude,
      },
    );

    final Map<String, dynamic>? saved = await fetchMitraBaseLocation();
    if (saved == null) {
      throw StateError('Lokasi Mitra berhasil disimpan, tetapi belum dapat dibaca kembali.');
    }
    return saved;
  }

  Future<Map<String, dynamic>?> fetchActiveContract() async {
    final dynamic result = await _client.rpc('get_active_mitra_contract');
    if (result is List && result.isNotEmpty && result.first is Map) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    if (result is Map && result.isNotEmpty) {
      return Map<String, dynamic>.from(result);
    }
    return null;
  }

  Future<void> acceptActiveContract(String version) async {
    final String platform = kIsWeb
        ? 'web'
        : defaultTargetPlatform.name.toLowerCase();
    await _client.rpc(
      'accept_active_mitra_contract',
      params: <String, dynamic>{
        'p_contract_version': version.trim(),
        'p_client_platform': platform,
      },
    );
  }

  Future<Map<String, dynamic>?> fetchMyApplication() async {
    final dynamic result = await _client.rpc('get_my_mitra_application');

    if (result is List && result.isNotEmpty && result.first is Map) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    return null;
  }

  Future<String> uploadDocument({
    required Uint8List bytes,
    required String originalName,
    required String documentType,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError('File dokumen kosong.');
    }
    if (bytes.lengthInBytes > 2 * 1024 * 1024) {
      throw ArgumentError('Ukuran dokumen maksimal 2 MB.');
    }

    String extension = originalName.contains('.')
        ? originalName.split('.').last.toLowerCase()
        : 'jpg';
    extension = extension.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (extension == 'jpeg') extension = 'jpg';
    if (!<String>['jpg', 'png', 'webp'].contains(extension)) {
      throw ArgumentError('Format dokumen harus JPG, PNG, atau WEBP.');
    }

    final String safeType = documentType.replaceAll(
      RegExp(r'[^a-z0-9_-]'),
      '',
    );
    final String path = '$currentUserId/'
        '${safeType}_${DateTime.now().microsecondsSinceEpoch}.$extension';

    final String contentType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    await _client.storage.from('mitra-documents').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
          ),
        );

    return path;
  }

  Future<Map<String, dynamic>> submitApplication({
    required String fullname,
    required String phone,
    required String address,
    required double latitude,
    required double longitude,
    required String bankName,
    required String accountNumber,
    required String ktmPath,
    required String selfiePath,
  }) async {
    await saveMitraBaseLocation(
      address: address,
      latitude: latitude,
      longitude: longitude,
    );

    await _client.rpc(
      'submit_mitra_application',
      params: <String, dynamic>{
        'p_fullname': fullname.trim(),
        'p_phone': phone.trim(),
        'p_address': address.trim(),
        'p_bank_name': bankName.trim(),
        'p_account_number': accountNumber.trim(),
        'p_ktm_path': ktmPath,
        'p_selfie_path': selfiePath,
        'p_terms_accepted': true,
      },
    );

    final Map<String, dynamic>? application = await fetchMyApplication();
    if (application == null) {
      throw StateError('Pengajuan berhasil dikirim, tetapi data belum terbaca.');
    }
    return application;
  }
}
