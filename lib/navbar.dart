import 'package:ayosuruh/mitra_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile.dart';
import 'job.dart';
import 'chat.dart';
import 'customer_dashboard.dart';

class MainNavigation extends StatefulWidget {
  final String? initialRole; // Opsional: Bisa di-pass dari halaman Login

  const MainNavigation({super.key, this.initialRole});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  final SupabaseClient _supabase = Supabase.instance.client;

  int _currentIndex = 0;
  int _dashboardRefreshTick = 0;
  
  String _userRole = 'user'; // Default role
  bool _isLoadingRole = true;

  // Palette Warna Navbar dari UI
  static const Color _navBgColor = Color(0xFFFAF7F5);
  static const Color _inactiveColor = Color(0xFF524538);
  static const Color _activeColor = Color(0xFF4B613E);
  static const Color _activePillBg = Color(0xFFF1F5ED);
  static const Color _borderColor = Color(0xFFF0ECE6);

  @override
  void initState() {
    super.initState();
    if (widget.initialRole != null && widget.initialRole!.isNotEmpty) {
      _userRole = widget.initialRole!.toLowerCase();
      _isLoadingRole = false;
    } else {
      _fetchUserRole();
    }
  }

  /* ---------- AMBIL ROLE DARI SUPABASE ---------- */
  Future<void> _fetchUserRole() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final res = await _supabase
            .from('users')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();

        if (mounted && res != null) {
          setState(() {
            _userRole = (res['role'] ?? 'user').toString().toLowerCase();
            _isLoadingRole = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching role in navbar: $e');
    }

    if (mounted) {
      setState(() => _isLoadingRole = false);
    }
  }

  void _changePage(int index) {
    setState(() {
      _currentIndex = index;

      if (index == 0) {
        _dashboardRefreshTick++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Tampilan Loading sejenak saat memeriksa role
    if (_isLoadingRole) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFA6623)),
        ),
      );
    }

    // Tentukan Dashboard berdasarkan Role
    final Widget activeDashboard = _userRole == 'mitra'
        ? MitraDashboardPage(key: ValueKey(_dashboardRefreshTick))
        : DashboardPage(key: ValueKey(_dashboardRefreshTick));

    final List<Widget> pages = [
      activeDashboard,        // Index 0: Dashboard (Mitra / Customer)
      const JobPage(),        // Index 1: Pekerjaan
      const ChatPage(),       // Index 2: Chat
      const ProfilePage(),    // Index 3: Profil
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: _navBgColor,
          border: Border(
            top: BorderSide(color: _borderColor, width: 1.0),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavButton(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  index: 0,
                ),
                _buildNavButton(
                  icon: Icons.work_outline_rounded,
                  activeIcon: Icons.work_rounded,
                  label: 'Jobs',
                  index: 1,
                ),
                _buildNavButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  activeIcon: Icons.chat_bubble_rounded,
                  label: 'Chat',
                  index: 2,
                ),
                _buildNavButton(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profile',
                  index: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () => _changePage(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        constraints: const BoxConstraints(minWidth: 72), // Menjaga lebar pill simetris
        decoration: BoxDecoration(
          color: isActive ? _activePillBg : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? _activeColor : _inactiveColor,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? _activeColor : _inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}