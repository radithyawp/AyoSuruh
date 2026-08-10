import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class PresenceService {
  PresenceService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  Timer? _heartbeat;
  bool _started = false;
  int _lifecycleGeneration = 0;

  String? get _userId => _client.auth.currentUser?.id;

  Future<void> start() async {
    if (_started || _userId == null) return;
    final int generation = ++_lifecycleGeneration;
    _started = true;
    await setOnline(true);
    if (!_started || generation != _lifecycleGeneration) return;

    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(setOnline(true));
    });
  }

  Future<void> stop() async {
    if (!_started && _heartbeat == null) return;
    final int generation = ++_lifecycleGeneration;
    _started = false;
    _heartbeat?.cancel();
    _heartbeat = null;
    await setOnline(false);

    // Bila app kembali ke foreground ketika update offline masih berjalan,
    // pastikan hasil request lama tidak meninggalkan status pengguna offline.
    if (generation != _lifecycleGeneration && _started) {
      await setOnline(true);
    }
  }

  Future<void> setOnline(bool online) async {
    final String? userId = _userId;
    if (userId == null) return;
    final String now = DateTime.now().toUtc().toIso8601String();
    try {
      await _client.from('user_presence').upsert(<String, dynamic>{
        'user_id': userId,
        'is_online': online,
        'last_seen': now,
        'updated_at': now,
      });
    } catch (_) {
      // Presence must never block core navigation/chat if the migration has not
      // reached a device yet or the connection briefly drops.
    }
  }

  Stream<List<Map<String, dynamic>>> visiblePresenceStream() {
    return _client
        .from('user_presence')
        .stream(primaryKey: <String>['user_id'])
        .map((rows) => List<Map<String, dynamic>>.from(rows));
  }

  Stream<List<Map<String, dynamic>>> userPresenceStream(String userId) {
    return _client
        .from('user_presence')
        .stream(primaryKey: <String>['user_id'])
        .eq('user_id', userId)
        .map((rows) => List<Map<String, dynamic>>.from(rows));
  }

  bool isOnline(Map<String, dynamic>? row) {
    if (row == null || row['is_online'] != true) return false;
    final DateTime? lastSeen = DateTime.tryParse(
      (row['last_seen'] ?? row['updated_at'] ?? '').toString(),
    )?.toUtc();
    if (lastSeen == null) return false;
    return DateTime.now().toUtc().difference(lastSeen) <
        const Duration(seconds: 100);
  }

  String presenceLabel(Map<String, dynamic>? row) {
    if (isOnline(row)) return 'Online';
    final DateTime? lastSeen = DateTime.tryParse(
      (row?['last_seen'] ?? row?['updated_at'] ?? '').toString(),
    )?.toLocal();
    if (lastSeen == null) return 'Offline';

    final Duration diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 1) return 'Terakhir aktif baru saja';
    if (diff.inMinutes < 60) return 'Terakhir aktif ${diff.inMinutes} mnt lalu';
    if (diff.inHours < 24) return 'Terakhir aktif ${diff.inHours} jam lalu';
    if (diff.inDays == 1) return 'Terakhir aktif kemarin';
    if (diff.inDays < 7) return 'Terakhir aktif ${diff.inDays} hari lalu';
    return 'Offline';
  }
}
