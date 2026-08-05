import 'package:flutter/material.dart';

class NotificationVisual {
  const NotificationVisual({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
}

NotificationVisual notificationVisual(String? type) {
  switch (type) {
    case 'bid_new':
      return const NotificationVisual(
        icon: Icons.local_offer_outlined,
        background: Color(0xFFFFE7C2),
        foreground: Color(0xFF9A5B00),
      );
    case 'bid_accepted':
      return const NotificationVisual(
        icon: Icons.work_outline_rounded,
        background: Color(0xFFDDF0CF),
        foreground: Color(0xFF4F6B3E),
      );
    case 'bid_rejected':
      return const NotificationVisual(
        icon: Icons.close_rounded,
        background: Color(0xFFFFE0DE),
        foreground: Color(0xFFB5473D),
      );
    case 'job_progress':
      return const NotificationVisual(
        icon: Icons.directions_walk_rounded,
        background: Color(0xFFFFE8C9),
        foreground: Color(0xFF9A5B00),
      );
    case 'job_completed':
      return const NotificationVisual(
        icon: Icons.check_circle_outline_rounded,
        background: Color(0xFFDDF0CF),
        foreground: Color(0xFF4F6B3E),
      );
    case 'job_cancelled':
      return const NotificationVisual(
        icon: Icons.cancel_outlined,
        background: Color(0xFFFFE0DE),
        foreground: Color(0xFFB5473D),
      );
    case 'chat_message':
      return const NotificationVisual(
        icon: Icons.chat_bubble_outline_rounded,
        background: Color(0xFFFFE7C2),
        foreground: Color(0xFF9A5B00),
      );
    case 'review_received':
      return const NotificationVisual(
        icon: Icons.star_outline_rounded,
        background: Color(0xFFFFE7C2),
        foreground: Color(0xFF9A5B00),
      );
    case 'mitra_application_submitted':
      return const NotificationVisual(
        icon: Icons.hourglass_top_rounded,
        background: Color(0xFFFFE7C2),
        foreground: Color(0xFF9A5B00),
      );
    case 'mitra_application_approved':
      return const NotificationVisual(
        icon: Icons.verified_outlined,
        background: Color(0xFFDDF0CF),
        foreground: Color(0xFF4F6B3E),
      );
    case 'mitra_application_rejected':
      return const NotificationVisual(
        icon: Icons.edit_note_rounded,
        background: Color(0xFFFFE0DE),
        foreground: Color(0xFFB5473D),
      );
    default:
      return const NotificationVisual(
        icon: Icons.notifications_none_rounded,
        background: Color(0xFFEDE8E4),
        foreground: Color(0xFF6A5D55),
      );
  }
}

String notificationRelativeTime(dynamic value) {
  if (value == null) return '';
  final DateTime? parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return '';

  final DateTime date = parsed.toLocal();
  final Duration difference = DateTime.now().difference(date);

  if (difference.isNegative || difference.inMinutes < 1) return 'Baru saja';
  if (difference.inMinutes < 60) return '${difference.inMinutes} menit lalu';
  if (difference.inHours < 24) return '${difference.inHours} jam lalu';
  if (difference.inDays < 7) return '${difference.inDays} hari lalu';
  const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]}';
}

String notificationGroupLabel(dynamic value) {
  final DateTime? parsed = DateTime.tryParse((value ?? '').toString());
  if (parsed == null) return 'SEBELUMNYA';

  final DateTime date = parsed.toLocal();
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime target = DateTime(date.year, date.month, date.day);
  final int dayDifference = today.difference(target).inDays;

  if (dayDifference <= 0) return 'HARI INI';
  if (dayDifference == 1) return 'KEMARIN';
  return 'SEBELUMNYA';
}
