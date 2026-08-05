import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JobService {
  JobService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get currentUserId {
    final String? id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Pengguna belum login.');
    }
    return id;
  }

  Future<String> getCurrentRole() async {
    final Map<String, dynamic>? result = await _client
        .from('users')
        .select('role')
        .eq('id', currentUserId)
        .maybeSingle();
    return (result?['role'] ?? 'user').toString().toLowerCase();
  }

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final dynamic result = await _client
        .from('categories')
        .select('id, name, icon')
        .order('name');
    return List<Map<String, dynamic>>.from(result as List);
  }

  Future<List<Map<String, dynamic>>> fetchMyAddresses() async {
    final dynamic result = await _client
        .from('addresses')
        .select('id, label, address, latitude, longitude, is_default')
        .eq('user_id', currentUserId)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result as List);
  }

  Future<Map<String, dynamic>?> fetchMyProfile() async {
    return _client
        .from('users')
        .select('id, fullname, phone, alamat, avatar_url, role')
        .eq('id', currentUserId)
        .maybeSingle();
  }

  Future<String> createJob({
    required String categoryId,
    required String title,
    required String description,
    required num budget,
    required DateTime scheduleDate,
    required String scheduleTime,
    String? addressId,
    String? newAddress,
    double? latitude,
    double? longitude,
  }) async {
    String? finalAddressId = addressId;

    if ((finalAddressId == null || finalAddressId.isEmpty) &&
        newAddress != null &&
        newAddress.trim().isNotEmpty) {
      final Map<String, dynamic> insertedAddress = await _client
          .from('addresses')
          .insert(<String, dynamic>{
            'user_id': currentUserId,
            'label': 'Lokasi Pekerjaan',
            'address': newAddress.trim(),
            'latitude': latitude,
            'longitude': longitude,
            'is_default': false,
          })
          .select('id')
          .single();
      finalAddressId = insertedAddress['id'].toString();
    }

    if (finalAddressId == null || finalAddressId.isEmpty) {
      throw ArgumentError('Alamat pekerjaan wajib dipilih atau diisi.');
    }

    final String dateValue = scheduleDate.toIso8601String().split('T').first;
    final Map<String, dynamic> insertedJob = await _client
        .from('jobs')
        .insert(<String, dynamic>{
          'customer_id': currentUserId,
          'category_id': categoryId,
          'title': title.trim(),
          'description': description.trim(),
          'budget': budget,
          'address_id': finalAddressId,
          'latitude': latitude,
          'longitude': longitude,
          'schedule_date': dateValue,
          'schedule_time': scheduleTime,
          'status': 'posted',
        })
        .select('id')
        .single();

    final String jobId = insertedJob['id'].toString();
    await _insertTimeline(
      jobId: jobId,
      status: 'posted',
      description: 'Pekerjaan dipublikasikan dan mulai mencari mitra.',
    );
    return jobId;
  }

  Future<List<Map<String, dynamic>>> fetchCustomerJobs() async {
    final dynamic result = await _client
        .from('jobs')
        .select('''
          id, customer_id, category_id, title, description, budget,
          address_id, latitude, longitude, schedule_date, schedule_time,
          status, progress_stage, created_at, mitra_id,
          categories(id, name, icon),
          addresses(id, label, address, latitude, longitude),
          mitra:users!jobs_mitra_id_fkey(id, fullname, avatar_url),
          bids(id, status, price),
          reviews(id, rating, review, tags, created_at)
        ''')
        .eq('customer_id', currentUserId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result as List);
  }

  Future<List<Map<String, dynamic>>> fetchAvailableJobs() async {
    final dynamic result = await _client
        .from('jobs')
        .select('''
          id, customer_id, category_id, title, description, budget,
          address_id, latitude, longitude, schedule_date, schedule_time,
          status, progress_stage, created_at, mitra_id,
          categories(id, name, icon),
          addresses(id, label, address, latitude, longitude),
          customer:users!jobs_customer_id_fkey(id, fullname, avatar_url),
          bids(id, mitra_id, status)
        ''')
        .inFilter('status', <String>['posted', 'waiting_bid'])
        .neq('customer_id', currentUserId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result as List);
  }

  Future<List<Map<String, dynamic>>> fetchMitraBids() async {
    final dynamic result = await _client
        .from('bids')
        .select('''
          id, job_id, mitra_id, price, estimated_time, message, status, created_at,
          jobs!bids_job_id_fkey(
            id, customer_id, title, description, budget, schedule_date,
            schedule_time, status, progress_stage, created_at, mitra_id,
            categories(id, name, icon),
            addresses(id, label, address, latitude, longitude),
            customer:users!jobs_customer_id_fkey(id, fullname, avatar_url)
          )
        ''')
        .eq('mitra_id', currentUserId)
        .neq('status', 'accepted')
        .order('created_at', ascending: false);

    // Penawaran yang sudah diterima dipindahkan ke tab Aktif. Setelah job
    // selesai, job tersebut akan tersedia di Riwayat Pekerjaan Mitra.
    return List<Map<String, dynamic>>.from(result as List).where((bid) {
      final dynamic rawJob = bid['jobs'];
      if (rawJob is! Map) return false;
      final String jobStatus = (rawJob['status'] ?? '').toString();
      return !<String>['completed', 'cancelled'].contains(jobStatus);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchMitraJobHistory() async {
    final dynamic result = await _client
        .from('jobs')
        .select('''
          id, customer_id, category_id, title, description, budget,
          address_id, latitude, longitude, schedule_date, schedule_time,
          status, progress_stage, created_at, mitra_id,
          categories(id, name, icon),
          addresses(id, label, address, latitude, longitude),
          customer:users!jobs_customer_id_fkey(id, fullname, avatar_url),
          reviews(id, rating, review, tags, created_at)
        ''')
        .eq('mitra_id', currentUserId)
        .inFilter('status', <String>['completed', 'cancelled'])
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result as List);
  }

  Future<List<Map<String, dynamic>>> fetchAssignedMitraJobs() async {
    final dynamic result = await _client
        .from('jobs')
        .select('''
          id, customer_id, category_id, title, description, budget,
          address_id, latitude, longitude, schedule_date, schedule_time,
          status, progress_stage, created_at, mitra_id,
          categories(id, name, icon),
          addresses(id, label, address, latitude, longitude),
          customer:users!jobs_customer_id_fkey(id, fullname, avatar_url)
        ''')
        .eq('mitra_id', currentUserId)
        .inFilter('status', <String>['accepted', 'on_progress'])
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result as List);
  }

  Future<Map<String, dynamic>> fetchMyJobAccess(String jobId) async {
    final dynamic response = await _client.rpc(
      'get_my_job_access',
      params: <String, dynamic>{'p_job_id': jobId},
    );

    if (response is List && response.isNotEmpty) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    return <String, dynamic>{
      'job_id': jobId,
      'is_selected_mitra': false,
      'my_bid_status': null,
    };
  }

  Future<Map<String, dynamic>> fetchJob(String jobId) async {
    final Map<String, dynamic> result = await _client
        .from('jobs')
        .select('''
          id, customer_id, category_id, title, description, budget,
          address_id, latitude, longitude, schedule_date, schedule_time,
          status, progress_stage, created_at, mitra_id,
          categories(id, name, icon),
          addresses(id, label, address, latitude, longitude),
          customer:users!jobs_customer_id_fkey(id, fullname, avatar_url, phone),
          mitra:users!jobs_mitra_id_fkey(id, fullname, avatar_url, phone),
          bids(id, mitra_id, price, estimated_time, message, status, created_at),
          reviews(id, rating, review, tags, created_at)
        ''')
        .eq('id', jobId)
        .single();

    if (!_hasProfile(result['customer'])) {
      final Map<String, dynamic>? customer =
          await _fetchJobParticipantProfile(jobId, 'customer');
      if (customer != null) result['customer'] = customer;
    }
    if (result['mitra_id'] != null && !_hasProfile(result['mitra'])) {
      final Map<String, dynamic>? mitra =
          await _fetchJobParticipantProfile(jobId, 'mitra');
      if (mitra != null) result['mitra'] = mitra;
    }
    return result;
  }

  bool _hasProfile(dynamic value) {
    return value is Map &&
        value['id'] != null &&
        value['fullname'] != null &&
        value['fullname'].toString().trim().isNotEmpty;
  }

  Future<Map<String, dynamic>?> _fetchJobParticipantProfile(
    String jobId,
    String participant,
  ) async {
    try {
      final dynamic result = await _client.rpc(
        'get_job_participant_profile',
        params: <String, dynamic>{
          'p_job_id': jobId,
          'p_participant': participant,
        },
      );
      if (result is List && result.isNotEmpty && result.first is Map) {
        return Map<String, dynamic>.from(result.first as Map);
      }
      if (result is Map) return Map<String, dynamic>.from(result);
    } catch (error) {
      debugPrint('Profil peserta job belum dapat dimuat: $error');
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchMyBidForJob(String jobId) async {
    return _client
        .from('bids')
        .select('id, job_id, mitra_id, price, estimated_time, message, status, created_at')
        .eq('job_id', jobId)
        .eq('mitra_id', currentUserId)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> fetchJobBids(String jobId) async {
    // Gunakan RPC security-definer agar customer pemilik job dapat membaca
    // profil para penawar tanpa membuka seluruh tabel public.users lewat RLS.
    try {
      final dynamic rpcResult = await _client.rpc(
        'get_job_bids_with_profiles',
        params: <String, dynamic>{'p_job_id': jobId},
      );

      if (rpcResult is List) {
        return rpcResult.whereType<Map>().map((Map row) {
          final Map<String, dynamic> item = Map<String, dynamic>.from(row);
          return <String, dynamic>{
            'id': item['id'],
            'job_id': item['job_id'],
            'mitra_id': item['mitra_id'],
            'price': item['price'],
            'estimated_time': item['estimated_time'],
            'message': item['message'],
            'status': item['status'],
            'created_at': item['created_at'],
            'mitra': <String, dynamic>{
              'id': item['mitra_id'],
              'rating': item['mitra_rating'],
              'is_active': item['mitra_is_active'],
              'user': <String, dynamic>{
                'id': item['mitra_id'],
                'fullname': item['mitra_fullname'],
                'avatar_url': item['mitra_avatar_url'],
                'phone': item['mitra_phone'],
              },
            },
          };
        }).toList();
      }
    } on PostgrestException catch (error) {
      final String message = error.message.toLowerCase();
      final bool functionMissing =
          message.contains('get_job_bids_with_profiles') &&
          (message.contains('not find') ||
              message.contains('does not exist') ||
              error.code == 'PGRST202');
      if (!functionMissing) rethrow;
      debugPrint(
        'RPC get_job_bids_with_profiles belum tersedia. Menggunakan query relasi: $error',
      );
    }

    // Fallback untuk project yang migration RPC-nya belum dijalankan.
    final dynamic result = await _client
        .from('bids')
        .select('''
          id, job_id, mitra_id, price, estimated_time, message, status, created_at,
          mitra:mitras!bids_mitra_id_fkey(
            id, rating, is_active,
            user:users!mitras_id_fkey(id, fullname, avatar_url, phone)
          )
        ''')
        .eq('job_id', jobId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(result as List);
  }
  Future<void> submitBid({
    required String jobId,
    required num price,
    required String estimatedTime,
    required String message,
  }) async {
    try {
      await _client.rpc(
        'submit_job_bid',
        params: <String, dynamic>{
          'p_job_id': jobId,
          'p_price': price,
          'p_estimated_time': estimatedTime.trim(),
          'p_message': message.trim(),
        },
      );
      return;
    } on PostgrestException catch (error) {
      final String lowerMessage = error.message.toLowerCase();
      final bool functionMissing = lowerMessage.contains('submit_job_bid') &&
          (lowerMessage.contains('not find') ||
              lowerMessage.contains('does not exist') ||
              error.code == 'PGRST202');
      if (!functionMissing) rethrow;
      debugPrint('RPC submit_job_bid belum tersedia. Menggunakan fallback: $error');
    }

    final Map<String, dynamic>? existing = await fetchMyBidForJob(jobId);
    if (existing != null) {
      throw StateError('Kamu sudah mengajukan penawaran untuk pekerjaan ini.');
    }

    await _client.from('bids').insert(<String, dynamic>{
      'job_id': jobId,
      'mitra_id': currentUserId,
      'price': price,
      'estimated_time': estimatedTime.trim(),
      'message': message.trim(),
      'status': 'pending',
    });

    final Map<String, dynamic>? job = await _client
        .from('jobs')
        .select('status')
        .eq('id', jobId)
        .maybeSingle();
    if (job?['status'] == 'posted') {
      try {
        await _client
            .from('jobs')
            .update(<String, dynamic>{'status': 'waiting_bid'})
            .eq('id', jobId)
            .eq('status', 'posted');
        await _insertTimeline(
          jobId: jobId,
          status: 'waiting_bid',
          description: 'Penawaran mitra mulai masuk.',
        );
      } catch (error) {
        debugPrint('Bid tersimpan, tetapi status job belum berubah: $error');
      }
    }
  }

  Future<void> acceptBid({
    required String jobId,
    required String bidId,
  }) async {
    try {
      await _client.rpc(
        'accept_job_bid',
        params: <String, dynamic>{
          'p_job_id': jobId,
          'p_bid_id': bidId,
        },
      );
      return;
    } on PostgrestException catch (error) {
      final String message = error.message.toLowerCase();
      final bool functionMissing = message.contains('accept_job_bid') &&
          (message.contains('not find') ||
              message.contains('does not exist') ||
              error.code == 'PGRST202');
      if (!functionMissing) rethrow;
      debugPrint('RPC accept_job_bid belum tersedia. Menggunakan fallback: $error');
    }

    await _acceptBidFallback(jobId: jobId, bidId: bidId);
  }

  Future<void> _acceptBidFallback({
    required String jobId,
    required String bidId,
  }) async {
    final Map<String, dynamic> job = await _client
        .from('jobs')
        .select('customer_id, status')
        .eq('id', jobId)
        .single();
    if (job['customer_id'] != currentUserId) {
      throw StateError('Hanya pemilik pekerjaan yang dapat memilih mitra.');
    }
    if (!<String>['posted', 'waiting_bid'].contains(job['status'])) {
      throw StateError('Pekerjaan ini sudah tidak menerima penawaran.');
    }

    final Map<String, dynamic> selectedBid = await _client
        .from('bids')
        .select('mitra_id, status')
        .eq('id', bidId)
        .eq('job_id', jobId)
        .single();

    await _client
        .from('bids')
        .update(<String, dynamic>{'status': 'rejected'})
        .eq('job_id', jobId)
        .neq('id', bidId)
        .eq('status', 'pending');
    await _client
        .from('bids')
        .update(<String, dynamic>{'status': 'accepted'})
        .eq('id', bidId);
    await _client.from('jobs').update(<String, dynamic>{
      'mitra_id': selectedBid['mitra_id'],
      'status': 'accepted',
    }).eq('id', jobId);
    await _insertTimeline(
      jobId: jobId,
      status: 'accepted',
      description: 'Customer memilih mitra untuk mengerjakan pekerjaan.',
    );
  }

  Future<void> rejectBid(String bidId) async {
    await _client
        .from('bids')
        .update(<String, dynamic>{'status': 'rejected'})
        .eq('id', bidId)
        .eq('status', 'pending');
  }

  Future<void> cancelJob(String jobId) async {
    final Map<String, dynamic> job = await _client
        .from('jobs')
        .select('customer_id, status')
        .eq('id', jobId)
        .single();
    if (job['customer_id'] != currentUserId) {
      throw StateError('Pekerjaan ini bukan milik akunmu.');
    }
    if (<String>['completed', 'cancelled'].contains(job['status'])) {
      throw StateError('Status pekerjaan tidak dapat diubah lagi.');
    }
    await _client
        .from('jobs')
        .update(<String, dynamic>{'status': 'cancelled'})
        .eq('id', jobId);
    await _client
        .from('bids')
        .update(<String, dynamic>{'status': 'rejected'})
        .eq('job_id', jobId)
        .eq('status', 'pending');
    await _insertTimeline(
      jobId: jobId,
      status: 'cancelled',
      description: 'Pekerjaan dibatalkan oleh customer.',
    );
  }

  Future<void> startJob(String jobId) async {
    try {
      await _client.rpc(
        'start_assigned_job',
        params: <String, dynamic>{'p_job_id': jobId},
      );
      return;
    } on PostgrestException catch (error) {
      final String lowerMessage = error.message.toLowerCase();
      final bool functionMissing = lowerMessage.contains('start_assigned_job') &&
          (lowerMessage.contains('not find') ||
              lowerMessage.contains('does not exist') ||
              error.code == 'PGRST202');
      if (!functionMissing) rethrow;
      debugPrint('RPC start_assigned_job belum tersedia. Menggunakan fallback: $error');
    }

    final Map<String, dynamic>? updated = await _client
        .from('jobs')
        .update(<String, dynamic>{'status': 'on_progress'})
        .eq('id', jobId)
        .eq('mitra_id', currentUserId)
        .eq('status', 'accepted')
        .select('id')
        .maybeSingle();
    if (updated == null) {
      throw StateError('Pekerjaan tidak dapat dimulai oleh akun ini.');
    }
    await _insertTimeline(
      jobId: jobId,
      status: 'on_progress',
      description: 'Mitra mulai mengerjakan pekerjaan.',
    );
  }

  Future<List<Map<String, dynamic>>> fetchJobTimelines(String jobId) async {
    final dynamic result = await _client
        .from('job_timelines')
        .select(
          'id, job_id, status, progress_stage, description, evidence_url, created_at',
        )
        .eq('job_id', jobId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(result as List);
  }

  Future<String> uploadJobEvidence({
    required String jobId,
    required Uint8List bytes,
    required String fileExtension,
    required String contentType,
  }) async {
    final String safeExtension = fileExtension
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .replaceFirst(RegExp(r'^jpeg$'), 'jpg');
    final String extension = safeExtension.isEmpty ? 'jpg' : safeExtension;
    final String path = '$currentUserId/$jobId/'
        '${DateTime.now().millisecondsSinceEpoch}.$extension';

    await _client.storage.from('job-evidence').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
          ),
        );
    return _client.storage.from('job-evidence').getPublicUrl(path);
  }

  Future<void> advanceJobProgress({
    required String jobId,
    required String progressStage,
    String? note,
    String? evidenceUrl,
  }) async {
    try {
      await _client.rpc(
        'advance_job_progress',
        params: <String, dynamic>{
          'p_job_id': jobId,
          'p_progress_stage': progressStage,
          'p_note': note?.trim(),
          'p_evidence_url': evidenceUrl,
        },
      );
    } on PostgrestException catch (error) {
      final String lowerMessage = error.message.toLowerCase();
      final bool functionMissing = lowerMessage.contains('advance_job_progress') &&
          (lowerMessage.contains('not find') ||
              lowerMessage.contains('does not exist') ||
              error.code == 'PGRST202');
      if (functionMissing) {
        throw StateError(
          'SQL progres pekerjaan belum dijalankan di Supabase. '
          'Jalankan migration 20260805_job_progress_feature.sql terlebih dahulu.',
        );
      }
      rethrow;
    }
  }

  Future<void> confirmJobCompletion(String jobId) async {
    try {
      await _client.rpc(
        'confirm_job_completion',
        params: <String, dynamic>{'p_job_id': jobId},
      );
    } on PostgrestException catch (error) {
      final String lowerMessage = error.message.toLowerCase();
      final bool functionMissing = lowerMessage.contains('confirm_job_completion') &&
          (lowerMessage.contains('not find') ||
              lowerMessage.contains('does not exist') ||
              error.code == 'PGRST202');
      if (functionMissing) {
        throw StateError(
          'SQL progres pekerjaan belum dijalankan di Supabase. '
          'Jalankan migration 20260805_job_progress_feature.sql terlebih dahulu.',
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchJobReview(String jobId) async {
    try {
      final dynamic result = await _client.rpc(
        'get_job_review',
        params: <String, dynamic>{'p_job_id': jobId},
      );
      if (result is List && result.isNotEmpty && result.first is Map) {
        return Map<String, dynamic>.from(result.first as Map);
      }
      if (result is Map) return Map<String, dynamic>.from(result);
      return null;
    } on PostgrestException catch (error) {
      final String lowerMessage = error.message.toLowerCase();
      final bool functionMissing = lowerMessage.contains('get_job_review') &&
          (lowerMessage.contains('not find') ||
              lowerMessage.contains('does not exist') ||
              error.code == 'PGRST202');
      if (!functionMissing) rethrow;
      debugPrint('RPC get_job_review belum tersedia. Menggunakan fallback: $error');
    }

    return _client
        .from('reviews')
        .select('id, job_id, customer_id, mitra_id, rating, review, tags, created_at')
        .eq('job_id', jobId)
        .maybeSingle();
  }

  Future<void> submitJobReview({
    required String jobId,
    required int rating,
    required String review,
    required List<String> tags,
  }) async {
    try {
      await _client.rpc(
        'submit_job_review',
        params: <String, dynamic>{
          'p_job_id': jobId,
          'p_rating': rating,
          'p_review': review.trim(),
          'p_tags': tags,
        },
      );
    } on PostgrestException catch (error) {
      final String lowerMessage = error.message.toLowerCase();
      final bool functionMissing = lowerMessage.contains('submit_job_review') &&
          (lowerMessage.contains('not find') ||
              lowerMessage.contains('does not exist') ||
              error.code == 'PGRST202');
      if (functionMissing) {
        throw StateError(
          'SQL rating mitra belum dijalankan di Supabase. '
          'Jalankan migration 20260805_job_review_feature.sql terlebih dahulu.',
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchMitraDashboardProfile() async {
    final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
      _client
          .from('users')
          .select('id, fullname, avatar_url, phone, role')
          .eq('id', currentUserId)
          .single(),
      _client
          .from('mitras')
          .select('id, rating, is_active')
          .eq('id', currentUserId)
          .maybeSingle(),
      _client
          .from('earnings')
          .select('amount')
          .eq('mitra_id', currentUserId),
      _client
          .from('jobs')
          .select('id')
          .eq('mitra_id', currentUserId)
          .eq('status', 'completed'),
    ]);

    final Map<String, dynamic> user =
        Map<String, dynamic>.from(result[0] as Map);
    final Map<String, dynamic>? mitra = result[1] == null
        ? null
        : Map<String, dynamic>.from(result[1] as Map);
    final List<dynamic> earnings = result[2] as List<dynamic>;
    final List<dynamic> completedJobs = result[3] as List<dynamic>;
    num totalEarnings = 0;
    for (final dynamic row in earnings) {
      if (row is Map) {
        final dynamic amount = row['amount'];
        totalEarnings += amount is num
            ? amount
            : num.tryParse(amount?.toString() ?? '') ?? 0;
      }
    }
    return <String, dynamic>{
      ...user,
      'rating': mitra?['rating'] ?? 0,
      'is_active': mitra?['is_active'] ?? false,
      'total_pendapatan': totalEarnings,
      'pekerjaan_selesai': completedJobs.length,
    };
  }

  Future<void> _insertTimeline({
    required String jobId,
    required String status,
    required String description,
  }) async {
    try {
      await _client.from('job_timelines').insert(<String, dynamic>{
        'job_id': jobId,
        'status': status,
        'description': description,
      });
    } catch (error) {
      debugPrint('Timeline tidak berhasil ditambahkan: $error');
    }
  }
}
