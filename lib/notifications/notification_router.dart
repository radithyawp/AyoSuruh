import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin/admin_mitras_page.dart';
import '../admin/admin_operations_page.dart';
import '../calls/voice_call_page.dart';
import '../calls/voice_call_service.dart';
import '../chats/chat_detail_page.dart';
import '../jobs/customer_job_detail_page.dart';
import '../jobs/job_bids_page.dart';
import '../jobs/mitra_job_detail_page.dart';
import '../mitra/mitra_application_page.dart';
import '../payments/job_payment_page.dart';
import '../wallet/mitra_wallet_page.dart';
import 'notification_service.dart' as in_app;

/// Satu pintu navigasi untuk notifikasi in-app maupun push FCM.
///
/// Push hanya membawa `notification_id` dan `type`. Router akan mengambil
/// record notifikasi lengkap dari Supabase agar tujuan seperti job, room chat,
/// pengajuan Mitra, dan payout tetap dapat dibuka tanpa memperbesar payload FCM.
class NotificationRouter {
  NotificationRouter._();

  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<bool> openFromPushData(
    BuildContext context,
    Map<String, dynamic> pushData, {
    required String activeMode,
  }) async {
    final Map<String, dynamic>? notification =
        await _hydrateNotification(pushData);
    if (notification == null || !context.mounted) return false;

    return open(
      context,
      notification,
      activeMode: activeMode,
    );
  }

  static Future<bool> open(
    BuildContext context,
    Map<String, dynamic> source, {
    required String activeMode,
  }) async {
    final Map<String, dynamic>? notification =
        await _hydrateNotification(source);
    if (notification == null || !context.mounted) return false;

    final String notificationId =
        _string(notification['id']) ?? _string(notification['notification_id']) ?? '';
    if (notificationId.isNotEmpty && notification['is_read'] != true) {
      try {
        await in_app.NotificationService().markAsRead(notificationId);
      } catch (_) {
        // Status baca bersifat best-effort dan tidak boleh memblokir navigasi.
      }
    }

    if (!context.mounted) return false;

    final String type = (_string(notification['type']) ?? '').toLowerCase();
    final String? roomId = _string(notification['room_id']);
    final String? jobId = _string(notification['job_id']);

    if (type == 'voice_call_incoming') {
      final String? callId = _voiceCallId(notification);
      if (callId == null) {
        return false;
      }
      if (VoiceCallPage.isOpen(callId)) {
        return true;
      }

      bool reserved = false;
      try {
        final Map<String, dynamic> call =
            await VoiceCallService().fetchCall(callId);
        if (!context.mounted) {
          return false;
        }

        reserved = VoiceCallPage.tryReserve(callId);
        if (!reserved) {
          return true;
        }

        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => VoiceCallPage(
              callId: callId,
              initialCall: call,
              incoming: true,
            ),
          ),
        );
        return true;
      } catch (_) {
        return false;
      } finally {
        if (reserved) {
          VoiceCallPage.release(callId);
        }
      }
    }

    if (type == 'admin_mitra_application_new') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const AdminMitrasPage(initialTab: 0),
        ),
      );
      return true;
    }

    if (type == 'admin_payout_requested') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const AdminMitrasPage(initialTab: 1),
        ),
      );
      return true;
    }

    if (type == 'admin_refund_review') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const AdminOperationsPage(initialTab: 2),
        ),
      );
      return true;
    }

    if (type.startsWith('mitra_application_')) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const MitraApplicationStatusPage(),
        ),
      );
      return true;
    }

    if (type.startsWith('payout_')) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const MitraWalletPage(),
        ),
      );
      return true;
    }

    if (type == 'chat_message' && roomId != null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ChatDetailPage(roomId: roomId),
        ),
      );
      return true;
    }

    if (jobId == null) return false;

    Map<String, dynamic>? job;
    try {
      final Map<String, dynamic>? row = await _supabase
          .from('jobs')
          .select('id, title, customer_id, mitra_id')
          .eq('id', jobId)
          .maybeSingle();
      job = row == null ? null : Map<String, dynamic>.from(row);
    } catch (_) {
      job = null;
    }

    if (!context.mounted) return false;

    final String currentUserId = _supabase.auth.currentUser?.id ?? '';
    final bool isJobMitra =
        currentUserId.isNotEmpty && _string(job?['mitra_id']) == currentUserId;
    final bool isJobCustomer =
        currentUserId.isNotEmpty && _string(job?['customer_id']) == currentUserId;
    final String jobTitle = _string(job?['title']) ?? 'Pekerjaan';

    if (type == 'bid_new') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => JobBidsPage(jobId: jobId),
        ),
      );
      return true;
    }

    if (_isPaymentOrRefund(type)) {
      if (isJobMitra) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => MitraJobDetailPage(jobId: jobId),
          ),
        );
      } else {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => JobPaymentPage(
              jobId: jobId,
              jobTitle: jobTitle,
            ),
          ),
        );
      }
      return true;
    }

    final bool preferMitra =
        isJobMitra ||
        (!isJobCustomer &&
            (type == 'bid_accepted' ||
                type == 'bid_rejected' ||
                type == 'review_received' ||
                type == 'job_completed' ||
                type == 'job_cancelled')) ||
        (!isJobCustomer &&
            !isJobMitra &&
            activeMode.trim().toLowerCase() == 'mitra');

    final Widget page = preferMitra
        ? MitraJobDetailPage(jobId: jobId)
        : CustomerJobDetailPage(jobId: jobId);

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => page),
    );
    return true;
  }

  static String? actionLabel(Map<String, dynamic> notification) {
    final String type = (_string(notification['type']) ?? '').toLowerCase();

    if (type == 'admin_mitra_application_new') return 'Buka verifikasi Mitra';
    if (type == 'admin_payout_requested') return 'Buka permintaan pencairan';
    if (type == 'admin_refund_review') return 'Buka review refund';
    if (type.startsWith('mitra_application_')) return 'Lihat status pengajuan';
    if (type.startsWith('payout_')) return 'Buka dompet Mitra';
    if (type == 'voice_call_incoming' && _voiceCallId(notification) != null) {
      return 'Buka panggilan';
    }
    if (type == 'chat_message' && _string(notification['room_id']) != null) {
      return 'Buka percakapan';
    }
    if (_isPaymentOrRefund(type) && _string(notification['job_id']) != null) {
      return 'Lihat pembayaran';
    }
    if (type == 'bid_new' && _string(notification['job_id']) != null) {
      return 'Lihat penawaran';
    }
    if (_string(notification['job_id']) != null) return 'Lihat pekerjaan';
    return null;
  }

  static bool _isPaymentOrRefund(String type) {
    return type.startsWith('payment_') || type.startsWith('refund_');
  }

  static Future<Map<String, dynamic>?> _hydrateNotification(
    Map<String, dynamic> source,
  ) async {
    final bool alreadyComplete =
        source.containsKey('job_id') ||
        source.containsKey('room_id') ||
        source.containsKey('data') ||
        source.containsKey('created_at');

    if (alreadyComplete) return Map<String, dynamic>.from(source);

    final String? notificationId =
        _string(source['notification_id']) ?? _string(source['id']);
    final String? userId = _supabase.auth.currentUser?.id;

    if (notificationId == null || userId == null) {
      return Map<String, dynamic>.from(source);
    }

    try {
      final Map<String, dynamic>? row = await _supabase
          .from('notifications')
          .select()
          .eq('id', notificationId)
          .eq('user_id', userId)
          .maybeSingle();

      if (row != null) return Map<String, dynamic>.from(row);
    } catch (_) {
      // Fallback ke payload FCM bila fetch gagal.
    }

    return Map<String, dynamic>.from(source);
  }

  static String? _voiceCallId(Map<String, dynamic> notification) {
    final dynamic data = notification['data'];
    if (data is Map) {
      return _string(data['call_id']);
    }
    return _string(notification['call_id']);
  }

  static String? _string(dynamic value) {
    final String text = (value ?? '').toString().trim();
    return text.isEmpty || text.toLowerCase() == 'null' ? null : text;
  }
}
