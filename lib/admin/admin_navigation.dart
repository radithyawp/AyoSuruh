import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin_dashboard_page.dart';
import 'admin_mitras_page.dart';
import 'admin_operations_page.dart';
import 'admin_settings_page.dart';
import 'admin_users_page.dart';
import '../notifications/notification_router.dart';
import '../services/notification_service.dart' as push_notifications;

class AdminNavigation extends StatefulWidget {
  const AdminNavigation({super.key});

  @override
  State<AdminNavigation> createState() => _AdminNavigationState();
}

class _AdminNavigationState extends State<AdminNavigation> {
  int _index = 0;
  int _refreshTick = 0;
  StreamSubscription<Map<String, dynamic>>? _notificationTapSubscription;

  static const Color _background = Color(0xFFFFFAFD);
  static const Color _brown = Color(0xFF7B4B00);
  static const Color _orange = Color(0xFFFF9800);
  static const Color _green = Color(0xFF5F784F);

  @override
  void initState() {
    super.initState();

    _notificationTapSubscription = push_notifications
        .NotificationService.instance.notificationTapStream
        .listen((Map<String, dynamic> data) {
      unawaited(_handleNotificationTap(data));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final Map<String, dynamic>? pending = push_notifications
          .NotificationService.instance
          .takePendingNotificationTap();
      if (pending != null) {
        unawaited(_handleNotificationTap(pending));
      }
    });
  }

  @override
  void dispose() {
    _notificationTapSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> data) async {
    if (!mounted) return;

    await NotificationRouter.openFromPushData(
      context,
      data,
      activeMode: 'admin',
    );
  }

  void _select(int index) {
    setState(() {
      _index = index;
      _refreshTick++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      AdminDashboardPage(
        key: ValueKey('admin-dashboard-$_refreshTick'),
        onOpenPartners: () => _select(2),
        onOpenOperations: () => _select(3),
      ),
      AdminUsersPage(key: ValueKey('admin-users-$_refreshTick')),
      AdminMitrasPage(key: ValueKey('admin-mitras-$_refreshTick')),
      AdminOperationsPage(key: ValueKey('admin-operations-$_refreshTick')),
      AdminSettingsPage(key: ValueKey('admin-settings-$_refreshTick')),
    ];

    return Scaffold(
      backgroundColor: _background,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int index) {
          HapticFeedback.selectionClick();
          _select(index);
        },
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE8F0E2),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, color: _brown),
            selectedIcon: Icon(Icons.dashboard_rounded, color: _green),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded, color: _brown),
            selectedIcon: Icon(Icons.people_rounded, color: _green),
            label: 'Pengguna',
          ),
          NavigationDestination(
            icon: Icon(Icons.handyman_outlined, color: _brown),
            selectedIcon: Icon(Icons.handyman_rounded, color: _green),
            label: 'Mitra',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined, color: _brown),
            selectedIcon: Icon(Icons.analytics_rounded, color: _green),
            label: 'Operasi',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: _brown),
            selectedIcon: Icon(Icons.settings_rounded, color: _orange),
            label: 'Setelan',
          ),
        ],
      ),
    );
  }
}
