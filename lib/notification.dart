import 'package:flutter/material.dart';

import 'chats/chat_detail_page.dart';
import 'jobs/customer_job_detail_page.dart';
import 'jobs/job_helpers.dart';
import 'jobs/mitra_job_detail_page.dart';
import 'notifications/notification_helpers.dart';
import 'notifications/notification_service.dart';
import 'mitra/mitra_application_page.dart';
import 'widgets/home_shortcut_button.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({
    super.key,
    this.activeMode = 'customer',
  });

  final String activeMode;

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final NotificationService _notificationService = NotificationService();
  late final Stream<List<Map<String, dynamic>>> _notificationStream;

  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    _notificationStream = _notificationService.notificationsStream();
  }

  String get _activeMode {
    final String value = widget.activeMode.trim().toLowerCase();
    return value == 'mitra' ? 'mitra' : 'customer';
  }

  Future<void> _markAllRead() async {
    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);
    try {
      await _notificationService.markAllAsRead();
    } catch (error) {
      if (!mounted) return;
      _showError('Notifikasi belum dapat ditandai dibaca: $error');
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _deleteAll() async {
    if (_isActionLoading) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Hapus semua notifikasi?'),
        content: const Text(
          'Riwayat notifikasi akan dihapus dari akun ini dan tidak dapat dikembalikan.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB5473D),
            ),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isActionLoading = true);
    try {
      await _notificationService.deleteAll();
    } catch (error) {
      if (!mounted) return;
      _showError('Notifikasi belum dapat dihapus: $error');
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    final String notificationId = (notification['id'] ?? '').toString();
    if (notificationId.isNotEmpty && notification['is_read'] != true) {
      try {
        await _notificationService.markAsRead(notificationId);
      } catch (_) {
        // Kegagalan status baca tidak boleh menghalangi navigasi utama.
      }
    }

    if (!mounted) return;

    final String? roomId = _nullableString(notification['room_id']);
    final String? jobId = _nullableString(notification['job_id']);
    final String type = (notification['type'] ?? '').toString();

    if (type.startsWith('mitra_application_')) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const MitraApplicationStatusPage(),
        ),
      );
      return;
    }

    if (type == 'chat_message' && roomId != null) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ChatDetailPage(roomId: roomId),
        ),
      );
      return;
    }

    if (jobId != null) {
      // Akun dual-mode tetap memiliki satu record user. Jangan memakai role
      // database untuk menentukan detail job karena role tersebut dapat tetap
      // `mitra` saat UI sedang berada di mode customer. Navigasi harus mengikuti
      // mode aktif ketika lonceng notifikasi dibuka.
      final Widget page = _activeMode == 'mitra'
          ? MitraJobDetailPage(jobId: jobId)
          : CustomerJobDetailPage(jobId: jobId);
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => page),
      );
    }
  }

  String? _nullableString(dynamic value) {
    final String text = (value ?? '').toString().trim();
    return text.isEmpty ? null : text;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: jobBackgroundColor,
      appBar: AppBar(
        backgroundColor: jobBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: jobBrownColor),
        ),
        title: const Text(
          'Notifikasi',
          style: TextStyle(
            color: jobDarkBrownColor,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          const HomeShortcutButton(),
          PopupMenuButton<String>(
            enabled: !_isActionLoading,
            color: Colors.white,
            icon: _isActionLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: jobBrownColor,
                    ),
                  )
                : const Icon(Icons.more_vert_rounded, color: jobBrownColor),
            onSelected: (String value) {
              if (value == 'read') _markAllRead();
              if (value == 'delete') _deleteAll();
            },
            itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'read',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.done_all_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Tandai semua dibaca'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.delete_outline_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Hapus semua'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _notificationStream,
        builder: (
          BuildContext context,
          AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: jobOrangeColor),
            );
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          final List<Map<String, dynamic>> notifications =
              snapshot.data ?? <Map<String, dynamic>>[];
          if (notifications.isEmpty) return _buildEmptyState();

          return RefreshIndicator(
            color: jobOrangeColor,
            onRefresh: () async {
              await Future<void>.delayed(const Duration(milliseconds: 350));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: _buildGroupedNotifications(notifications),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildGroupedNotifications(
    List<Map<String, dynamic>> notifications,
  ) {
    final Map<String, List<Map<String, dynamic>>> groups =
        <String, List<Map<String, dynamic>>>{
      'HARI INI': <Map<String, dynamic>>[],
      'KEMARIN': <Map<String, dynamic>>[],
      'SEBELUMNYA': <Map<String, dynamic>>[],
    };

    for (final Map<String, dynamic> notification in notifications) {
      final String label = notificationGroupLabel(notification['created_at']);
      groups[label]!.add(notification);
    }

    final List<Widget> widgets = <Widget>[];
    for (final String label in <String>['HARI INI', 'KEMARIN', 'SEBELUMNYA']) {
      final List<Map<String, dynamic>> rows = groups[label]!;
      if (rows.isEmpty) continue;
      widgets.add(
        Padding(
          padding: EdgeInsets.only(
            left: 2,
            top: widgets.isEmpty ? 2 : 20,
            bottom: 8,
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF75685F),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ),
      );
      widgets.addAll(rows.map(_buildNotificationCard));
    }

    widgets.add(
      const Padding(
        padding: EdgeInsets.only(top: 28, bottom: 4),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.notifications_off_outlined,
              color: Color(0xFFD4CBC5),
              size: 34,
            ),
            SizedBox(height: 8),
            Text(
              'Tidak ada notifikasi lama lainnya',
              style: TextStyle(
                color: Color(0xFFB7ACA5),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
    return widgets;
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final bool isUnread = notification['is_read'] != true;
    final String type = (notification['type'] ?? '').toString();
    final NotificationVisual visual = notificationVisual(type);
    final bool hasDestination =
        _nullableString(notification['room_id']) != null ||
            _nullableString(notification['job_id']) != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isUnread ? const Color(0xFFFFF4E9) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: () => _openNotification(notification),
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isUnread
                    ? const Color(0xFFFFD2A0)
                    : const Color(0xFFECE3DE),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: visual.background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    visual.icon,
                    color: visual.foreground,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              (notification['title'] ?? 'Notifikasi').toString(),
                              style: TextStyle(
                                color: const Color(0xFF332C28),
                                fontSize: 13,
                                fontWeight:
                                    isUnread ? FontWeight.w900 : FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            notificationRelativeTime(
                              notification['created_at'],
                            ),
                            style: const TextStyle(
                              color: Color(0xFF9A8E87),
                              fontSize: 9,
                            ),
                          ),
                          if (isUnread) ...<Widget>[
                            const SizedBox(width: 7),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: jobOrangeColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        (notification['body'] ?? '').toString(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6C6059),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                      if (hasDestination) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          type == 'chat_message'
                              ? 'Buka percakapan'
                              : 'Lihat pekerjaan',
                          style: const TextStyle(
                            color: jobBrownColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: Color(0xFFFFEEDB),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: jobBrownColor,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Belum Ada Notifikasi',
              style: TextStyle(
                color: Color(0xFF332C28),
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Pembaruan pekerjaan, penawaran, chat, dan rating akan tampil di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF847870),
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFB5473D),
              size: 44,
            ),
            const SizedBox(height: 12),
            const Text(
              'Notifikasi belum dapat dimuat',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF7D716A),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationBell extends StatefulWidget {
  const NotificationBell({
    super.key,
    this.color = jobDarkBrownColor,
    this.size = 26,
    this.activeMode = 'customer',
  });

  final Color color;
  final double size;
  final String activeMode;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final NotificationService _notificationService = NotificationService();
  late final Stream<int> _unreadStream;

  @override
  void initState() {
    super.initState();
    _unreadStream = _notificationService.unreadCountStream();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _unreadStream,
      builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
        final int unreadCount = snapshot.data ?? 0;
        return IconButton(
          tooltip: 'Notifikasi',
          onPressed: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => NotificationPage(
                  activeMode: widget.activeMode,
                ),
              ),
            );
          },
          icon: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Icon(
                Icons.notifications_none_rounded,
                color: widget.color,
                size: widget.size,
              ),
              if (unreadCount > 0)
                Positioned(
                  right: -5,
                  top: -5,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
