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

  /* ---------- HALAMAN DINAMIS SESUAI ROLE ---------- */
  List<Widget> get _pages {
    // Tentukan Dashboard di Tab 0 berdasarkan Role
    Widget activeDashboard;
    if (_userRole == 'mitra') {
      activeDashboard = MitraDashboardPage(key: ValueKey(_dashboardRefreshTick));
    } else {
      activeDashboard = DashboardPage(key: ValueKey(_dashboardRefreshTick));
    }

    return [
      activeDashboard,        // Index 0: Dashboard (Mitra / Customer)
      const JobPage(),        // Index 1: Pekerjaan
      const ChatPage(),       // Index 2: Chat
      const ProfilePage(),    // Index 3: Profil
    ];
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

    return Scaffold(
      backgroundColor: Colors.white,
      // Body langsung menampilkan halaman aktif
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),

      // Fixed Navbar diletakkan di properti bottomNavigationBar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2D3134),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -2), // Bayangan mengarah ke atas
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavButton(icon: Icons.home_rounded, index: 0),        // Beranda
                _buildNavButton(icon: Icons.work_rounded, index: 1),        // Pekerjaan
                _buildNavButton(icon: Icons.chat_bubble_rounded, index: 2), // Chat
                _buildNavButton(icon: Icons.person_rounded, index: 3),      // Profil
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton({required IconData icon, required int index}) {
    final isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () => _changePage(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFA6623) : const Color(0xFF43494D),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}