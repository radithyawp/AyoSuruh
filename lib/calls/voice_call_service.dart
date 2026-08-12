import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveKitCallCredentials {
  const LiveKitCallCredentials({
    required this.serverUrl,
    required this.participantToken,
  });

  final String serverUrl;
  final String participantToken;
}

class VoiceCallService {
  VoiceCallService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get currentUserId {
    final String? id = _client.auth.currentUser?.id;
    if (id == null || id.isEmpty) {
      throw StateError('Pengguna belum login.');
    }
    return id;
  }

  Future<bool> ensureCallPermissions() async {
    final PermissionStatus microphone = await Permission.microphone.request();
    if (!microphone.isGranted) {
      return false;
    }

    // Bluetooth permissions below are Android-specific. The call itself still
    // works through earpiece/speaker when headset access is unavailable.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await Permission.bluetooth.request();
        await Permission.bluetoothConnect.request();
      } catch (_) {
        // Earpiece/speaker calling remains available without Bluetooth access.
      }
    }

    return true;
  }

  Future<Map<String, dynamic>> startCall(String roomId) async {
    final dynamic result = await _client.rpc(
      'create_voice_call',
      params: <String, dynamic>{'p_room_id': roomId},
    );
    return _asMap(result, 'Panggilan belum dapat dibuat.');
  }

  Future<Map<String, dynamic>> fetchCall(String callId) async {
    final dynamic result = await _client.rpc(
      'get_voice_call',
      params: <String, dynamic>{'p_call_id': callId},
    );
    return _asMap(result, 'Panggilan tidak ditemukan.');
  }

  Future<Map<String, dynamic>?> fetchPendingIncomingCall() async {
    final dynamic result = await _client.rpc('get_pending_incoming_voice_call');
    if (result == null) {
      return null;
    }
    return _asMap(result, 'Panggilan masuk tidak ditemukan.');
  }

  Stream<List<Map<String, dynamic>>> incomingCallsStream() {
    return _client
        .from('voice_calls')
        .stream(primaryKey: <String>['id'])
        .eq('callee_id', currentUserId)
        .map((List<Map<String, dynamic>> rows) {
      final List<Map<String, dynamic>> ringing = rows
          .where((Map<String, dynamic> row) => row['status'] == 'ringing')
          .map((Map<String, dynamic> row) => Map<String, dynamic>.from(row))
          .toList();
      ringing.sort((Map<String, dynamic> left, Map<String, dynamic> right) {
        final DateTime? a = DateTime.tryParse((left['created_at'] ?? '').toString());
        final DateTime? b = DateTime.tryParse((right['created_at'] ?? '').toString());
        if (a == null && b == null) {
          return 0;
        }
        if (a == null) {
          return 1;
        }
        if (b == null) {
          return -1;
        }
        return b.compareTo(a);
      });
      return ringing;
    });
  }

  Stream<Map<String, dynamic>?> callStream(String callId) {
    return _client
        .from('voice_calls')
        .stream(primaryKey: <String>['id'])
        .eq('id', callId)
        .map((List<Map<String, dynamic>> rows) {
      if (rows.isEmpty) {
        return null;
      }
      return Map<String, dynamic>.from(rows.first);
    });
  }

  Future<Map<String, dynamic>> respond({
    required String callId,
    required bool accept,
  }) async {
    final dynamic result = await _client.rpc(
      'respond_voice_call',
      params: <String, dynamic>{
        'p_call_id': callId,
        'p_accept': accept,
      },
    );
    return _asMap(result, 'Respons panggilan belum dapat diproses.');
  }

  Future<Map<String, dynamic>> cancel(String callId) async {
    final dynamic result = await _client.rpc(
      'cancel_voice_call',
      params: <String, dynamic>{'p_call_id': callId},
    );
    return _asMap(result, 'Panggilan belum dapat dibatalkan.');
  }

  Future<Map<String, dynamic>> markConnected(String callId) async {
    final dynamic result = await _client.rpc(
      'mark_voice_call_connected',
      params: <String, dynamic>{'p_call_id': callId},
    );
    return _asMap(result, 'Status panggilan belum dapat diperbarui.');
  }

  Future<Map<String, dynamic>> end(String callId) async {
    final dynamic result = await _client.rpc(
      'end_voice_call',
      params: <String, dynamic>{'p_call_id': callId},
    );
    return _asMap(result, 'Panggilan belum dapat diakhiri.');
  }

  Future<LiveKitCallCredentials> fetchLiveKitCredentials(String callId) async {
    final response = await _client.functions.invoke(
      'livekit-call-token',
      body: <String, dynamic>{'call_id': callId},
    );

    final dynamic data = response.data;
    if (data is! Map) {
      throw StateError('Server panggilan memberikan respons yang tidak valid.');
    }

    final Map<String, dynamic> map = Map<String, dynamic>.from(data);
    if (map['error'] != null) {
      throw StateError(map['error'].toString());
    }

    final String serverUrl = (map['server_url'] ?? '').toString().trim();
    final String participantToken =
        (map['participant_token'] ?? '').toString().trim();
    if (serverUrl.isEmpty || participantToken.isEmpty) {
      throw StateError('Kredensial panggilan belum lengkap.');
    }

    return LiveKitCallCredentials(
      serverUrl: serverUrl,
      participantToken: participantToken,
    );
  }

  Map<String, dynamic> _asMap(dynamic value, String fallbackMessage) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    throw StateError(fallbackMessage);
  }
}
