import 'package:flutter/material.dart';

import 'admin_dashboard_page.dart';
import 'admin_mitras_page.dart';
import 'admin_settings_page.dart';
import 'admin_users_page.dart';

class AdminNavigation extends StatefulWidget {
  const AdminNavigation({super.key});

  @override
  State<AdminNavigation> createState() => _AdminNavigationState();
}

class _AdminNavigationState extends State<AdminNavigation> {
  int _index = 0;
  int _refreshTick = 0;

  static const Color _background = Color(0xFFFFFAFD);
  static const Color _brown = Color(0xFF7B4B00);
  static const Color _orange = Color(0xFFFF9800);
  static const Color _green = Color(0xFF5F784F);

  void _select(int index) {
    setState(() {
      _index = index;
      _refreshTick++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      AdminDashboardPage(key: ValueKey('admin-dashboard-$_refreshTick')),
      AdminUsersPage(key: ValueKey('admin-users-$_refreshTick')),
      AdminMitrasPage(key: ValueKey('admin-mitras-$_refreshTick')),
      AdminSettingsPage(key: ValueKey('admin-settings-$_refreshTick')),
    ];

    return Scaffold(
      backgroundColor: _background,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE8F0E2),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, color: _brown),
            selectedIcon: Icon(Icons.dashboard_rounded, color: _green),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded, color: _brown),
            selectedIcon: Icon(Icons.people_rounded, color: _green),
            label: 'Users',
          ),
          NavigationDestination(
            icon: Icon(Icons.handyman_outlined, color: _brown),
            selectedIcon: Icon(Icons.handyman_rounded, color: _green),
            label: 'Partners',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: _brown),
            selectedIcon: Icon(Icons.settings_rounded, color: _orange),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
