import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  NotificationService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get currentUserId {
    final String? id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Pengguna belum login.');
    }
    return id;
  }

  Stream<List<Map<String, dynamic>>> notificationsStream() {
    return _client
        .from('notifications')
        .stream(primaryKey: <String>['id'])
        .eq('user_id', currentUserId)
        .order('created_at', ascending: false)
        .map((List<Map<String, dynamic>> rows) {
      final List<Map<String, dynamic>> sorted =
          List<Map<String, dynamic>>.from(rows);
      sorted.sort((Map<String, dynamic> left, Map<String, dynamic> right) {
        final DateTime? leftDate = DateTime.tryParse(
          (left['created_at'] ?? '').toString(),
        );
        final DateTime? rightDate = DateTime.tryParse(
          (right['created_at'] ?? '').toString(),
        );
        if (leftDate == null && rightDate == null) return 0;
        if (leftDate == null) return 1;
        if (rightDate == null) return -1;
        return rightDate.compareTo(leftDate);
      });
      return sorted;
    });
  }

  Stream<int> unreadCountStream() {
    return notificationsStream().map(
      (List<Map<String, dynamic>> rows) => rows
          .where((Map<String, dynamic> row) => row['is_read'] != true)
          .length,
    );
  }

  Future<String> fetchCurrentRole() async {
    final Map<String, dynamic>? row = await _client
        .from('users')
        .select('role')
        .eq('id', currentUserId)
        .maybeSingle();
    return (row?['role'] ?? 'user').toString().toLowerCase();
  }

  Future<void> markAsRead(String notificationId) async {
    await _client
        .from('notifications')
        .update(<String, dynamic>{'is_read': true})
        .eq('id', notificationId)
        .eq('user_id', currentUserId);
  }

  Future<void> markAllAsRead() async {
    await _client
        .from('notifications')
        .update(<String, dynamic>{'is_read': true})
        .eq('user_id', currentUserId)
        .eq('is_read', false);
  }

  Future<void> deleteAll() async {
    await _client
        .from('notifications')
        .delete()
        .eq('user_id', currentUserId);
  }

  Future<void> markRoomNotificationsRead(String roomId) async {
    try {
      await _client.rpc(
        'mark_room_notifications_read',
        params: <String, dynamic>{'p_room_id': roomId},
      );
    } on PostgrestException catch (error) {
      if (!_isMissingFunction(error, 'mark_room_notifications_read')) rethrow;
    }
  }

  Future<void> markJobNotificationsRead(String jobId) async {
    try {
      await _client.rpc(
        'mark_job_notifications_read',
        params: <String, dynamic>{'p_job_id': jobId},
      );
    } on PostgrestException catch (error) {
      if (!_isMissingFunction(error, 'mark_job_notifications_read')) rethrow;
    }
  }

  bool _isMissingFunction(PostgrestException error, String functionName) {
    final String message = error.message.toLowerCase();
    return error.code == 'PGRST202' ||
        (message.contains(functionName.toLowerCase()) &&
            (message.contains('not find') || message.contains('does not exist')));
  }
}
