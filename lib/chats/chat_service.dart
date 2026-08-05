import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  ChatService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get currentUserId {
    final String? id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Pengguna belum login.');
    }
    return id;
  }

  Future<List<Map<String, dynamic>>> fetchMyRooms() async {
    // Membuka daftar chat menandakan pesan sudah sampai ke perangkat penerima,
    // tetapi belum dianggap dibaca sampai room percakapannya benar-benar dibuka.
    await markMyMessagesDelivered();

    final dynamic result = await _client.rpc('get_my_chat_rooms');
    if (result is! List) return <Map<String, dynamic>>[];
    return List<Map<String, dynamic>>.from(result);
  }

  Future<String> getOrCreateJobRoom(String jobId) async {
    final dynamic result = await _client.rpc(
      'get_or_create_job_chat_room',
      params: <String, dynamic>{'p_job_id': jobId},
    );

    if (result is String && result.isNotEmpty) return result;
    if (result is Map && result['id'] != null) {
      return result['id'].toString();
    }
    if (result is List && result.isNotEmpty) {
      final dynamic first = result.first;
      if (first is String) return first;
      if (first is Map) {
        final dynamic value = first['get_or_create_job_chat_room'] ??
            first['room_id'] ??
            first['id'];
        if (value != null) return value.toString();
      }
    }

    throw StateError('Room chat belum dapat dibuat.');
  }

  Future<Map<String, dynamic>> fetchRoomHeader(String roomId) async {
    final dynamic result = await _client.rpc(
      'get_chat_room_header',
      params: <String, dynamic>{'p_room_id': roomId},
    );

    if (result is List && result.isNotEmpty && result.first is Map) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    if (result is Map) return Map<String, dynamic>.from(result);
    throw StateError('Percakapan tidak ditemukan atau tidak dapat diakses.');
  }

  Stream<List<Map<String, dynamic>>> messagesStream(String roomId) {
    return _client
        .from('messages')
        .stream(primaryKey: <String>['id'])
        .eq('room_id', roomId)
        .map((List<Map<String, dynamic>> rows) {
      final List<Map<String, dynamic>> sorted =
          List<Map<String, dynamic>>.from(rows);

      // Sorting dilakukan kembali di client karena event realtime tidak selalu
      // mempertahankan urutan query awal. Pesan lama di atas, terbaru di bawah.
      sorted.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
        final DateTime? left = DateTime.tryParse(
          (a['created_at'] ?? '').toString(),
        );
        final DateTime? right = DateTime.tryParse(
          (b['created_at'] ?? '').toString(),
        );

        if (left == null && right == null) {
          return (a['id'] ?? '').toString().compareTo(
                (b['id'] ?? '').toString(),
              );
        }
        if (left == null) return -1;
        if (right == null) return 1;

        final int byDate = left.compareTo(right);
        if (byDate != 0) return byDate;
        return (a['id'] ?? '').toString().compareTo(
              (b['id'] ?? '').toString(),
            );
      });

      return sorted;
    });
  }

  Stream<List<Map<String, dynamic>>> visibleMessagesStream() {
    return _client
        .from('messages')
        .stream(primaryKey: <String>['id'])
        .order('created_at', ascending: false)
        .map((List<Map<String, dynamic>> rows) =>
            List<Map<String, dynamic>>.from(rows));
  }

  Future<void> sendMessage({
    required String roomId,
    required String message,
  }) async {
    final String cleaned = message.trim();
    if (cleaned.isEmpty) {
      throw ArgumentError('Pesan tidak boleh kosong.');
    }

    await _client.rpc(
      'send_chat_message',
      params: <String, dynamic>{
        'p_room_id': roomId,
        'p_message': cleaned,
      },
    );
  }

  Future<String> uploadChatImage({
    required String roomId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError('File foto kosong.');
    }
    if (bytes.lengthInBytes > 8 * 1024 * 1024) {
      throw ArgumentError('Ukuran foto maksimal 8 MB.');
    }

    String extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'jpg';
    extension = extension
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .replaceFirst(RegExp(r'^jpeg$'), 'jpg');
    if (extension.isEmpty) extension = 'jpg';

    final String path = '$currentUserId/$roomId/'
        '${DateTime.now().microsecondsSinceEpoch}.$extension';

    await _client.storage.from('chat-attachments').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
          ),
        );

    return _client.storage.from('chat-attachments').getPublicUrl(path);
  }

  Future<void> sendImageMessage({
    required String roomId,
    required String attachmentUrl,
    required String attachmentName,
    required String attachmentMimeType,
    required int attachmentSize,
    String? caption,
  }) async {
    try {
      await _client.rpc(
        'send_chat_attachment',
        params: <String, dynamic>{
          'p_room_id': roomId,
          'p_attachment_url': attachmentUrl,
          'p_attachment_name': attachmentName,
          'p_attachment_mime_type': attachmentMimeType,
          'p_attachment_size': attachmentSize,
          'p_caption': caption?.trim(),
        },
      );
    } on PostgrestException catch (error) {
      final String message = error.message.toLowerCase();
      if (error.code == 'PGRST202' ||
          (message.contains('send_chat_attachment') &&
              message.contains('not find'))) {
        throw StateError(
          'SQL peningkatan chat belum dijalankan di Supabase.',
        );
      }
      rethrow;
    }
  }

  Future<void> markMyMessagesDelivered() async {
    try {
      await _client.rpc('mark_my_chat_messages_delivered');
    } on PostgrestException catch (error) {
      if (!_isMissingFunction(error, 'mark_my_chat_messages_delivered')) {
        rethrow;
      }
    }
  }

  Future<void> markRoomMessagesRead(String roomId) async {
    try {
      await _client.rpc(
        'mark_chat_messages_read',
        params: <String, dynamic>{'p_room_id': roomId},
      );
    } on PostgrestException catch (error) {
      if (!_isMissingFunction(error, 'mark_chat_messages_read')) {
        rethrow;
      }
    }

    try {
      await _client.rpc(
        'mark_room_notifications_read',
        params: <String, dynamic>{'p_room_id': roomId},
      );
    } on PostgrestException catch (error) {
      if (!_isMissingFunction(error, 'mark_room_notifications_read')) {
        rethrow;
      }
    }
  }

  bool _isMissingFunction(PostgrestException error, String functionName) {
    final String message = error.message.toLowerCase();
    return error.code == 'PGRST202' ||
        (message.contains(functionName.toLowerCase()) &&
            (message.contains('not find') || message.contains('does not exist')));
  }
}
