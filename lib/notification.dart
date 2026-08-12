import 'package:flutter/material.dart';

import 'jobs/job_helpers.dart';
import 'notifications/notification_helpers.dart';
import 'notifications/notification_router.dart';
import 'notifications/notification_service.dart';
import 'widgets/home_shortcut_button.dart';
import 'widgets/ayo_pressable.dart';
import 'widgets/ayo_empty_state.dart';
import 'widgets/ayo_snackbar.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';

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
    if (value == 'admin') return 'admin';
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
        title: const AyoText('Hapus semua notifikasi?'),
        content: const AyoText(
          'Riwayat notifikasi akan dihapus dari akun ini dan tidak dapat dikembalikan.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AyoText('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB5473D),
            ),
            child: const AyoText('Hapus Semua'),
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
    try {
      final bool opened = await NotificationRouter.open(
        context,
        notification,
        activeMode: _activeMode,
      );

      if (!opened && mounted) {
        AyoSnackBar.info(
          context,
          'Notifikasi ini belum memiliki halaman tujuan.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      _showError('Halaman notifikasi belum dapat dibuka: $error');
    }
  }

  void _showError(String message) {
    AyoSnackBar.error(context, message);
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
          icon: Icon(Icons.arrow_back_rounded, color: jobBrownColor),
        ),
        title: AyoText(
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
            color: Theme.of(context).colorScheme.surface,
            icon: _isActionLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: jobBrownColor,
                    ),
                  )
                : Icon(Icons.more_vert_rounded, color: jobBrownColor),
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
                    AyoText('Tandai semua dibaca'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.delete_outline_rounded, size: 20),
                    SizedBox(width: 10),
                    AyoText('Hapus semua'),
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
          child: AyoText(
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
            AyoText(
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
    final String? actionLabel =
        NotificationRouter.actionLabel(notification);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isUnread
            ? Color.alphaBlend(
                jobOrangeColor.withValues(alpha: 0.10),
                Theme.of(context).colorScheme.surface,
              )
            : Theme.of(context).colorScheme.surface,
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
                    ? jobOrangeColor.withValues(alpha: 0.45)
                    : Theme.of(context).dividerColor,
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
                            child: AyoText(
                              AyoI18n.notificationText(
                                (notification['title'] ?? 'Notifikasi').toString(),
                              ),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 13,
                                fontWeight:
                                    isUnread ? FontWeight.w900 : FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          AyoText(
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
                      AyoText(
                        AyoI18n.notificationText(
                          (notification['body'] ?? '').toString(),
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                      if (actionLabel != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            AyoText(
                              actionLabel,
                              style: TextStyle(
                                color: jobBrownColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 13,
                              color: jobBrownColor,
                            ),
                          ],
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
    return const AyoEmptyState(
      assetPath: 'assets/images/ayos/ayos_sleep.png',
      badgeIcon: Icons.notifications_none_rounded,
      title: 'Belum ada notifikasi',
      description:
          'Pembaruan pekerjaan, penawaran, chat, pembayaran, dan rating akan tampil di sini.',
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
            const AyoText(
              'Notifikasi belum dapat dimuat',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            AyoText(
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
    this.color,
    this.size = 26,
    this.activeMode = 'customer',
  });

  final Color? color;
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
        return Tooltip(
          message: 'Notifikasi',
          child: AyoPressable(
            haptic: true,
            pressedScale: 0.9,
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => NotificationPage(
                    activeMode: widget.activeMode,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Icon(
                    Icons.notifications_none_rounded,
                    color: widget.color ?? jobDarkBrownColor,
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
                          border: Border.all(color: Theme.of(context).colorScheme.surface, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: AyoText(
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
            ),
          ),
        );
      },
    );
  }
}
