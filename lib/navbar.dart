import 'package:ayosuruh/mitra_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat.dart';
import 'customer_dashboard.dart';
import 'job.dart';
import 'profile.dart';

class MainNavigation extends StatefulWidget {
  /// Mode awal opsional. Nilai yang didukung: `customer` / `user` / `mitra`.
  ///
  /// `mitra` hanya digunakan bila akun benar-benar mempunyai record aktif pada
  /// tabel `public.mitras`.
  final String? initialRole;

  const MainNavigation({super.key, this.initialRole});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  final SupabaseClient _supabase = Supabase.instance.client;

  int _currentIndex = 0;
  int _dashboardRefreshTick = 0;
  int _jobsRefreshTick = 0;
  int _profileRefreshTick = 0;

  String _activeMode = 'customer';
  bool _canUseMitraMode = false;
  bool _isLoadingAccess = true;

  static const Color _navBgColor = Color(0xFFFAF7F5);
  static const Color _inactiveColor = Color(0xFF524538);
  static const Color _activeColor = Color(0xFF4B613E);
  static const Color _activePillBg = Color(0xFFF1F5ED);
  static const Color _borderColor = Color(0xFFF0ECE6);

  @override
  void initState() {
    super.initState();
    _fetchUserAccess();
  }

  String? _normalizeMode(String? value) {
    final String normalized = (value ?? '').trim().toLowerCase();
    if (normalized == 'mitra') return 'mitra';
    if (normalized == 'user' ||
        normalized == 'customer' ||
        normalized == 'pelanggan') {
      return 'customer';
    }
    return null;
  }

  Future<void> _fetchUserAccess() async {
    try {
      final User? authUser = _supabase.auth.currentUser;
      if (authUser == null) {
        if (mounted) setState(() => _isLoadingAccess = false);
        return;
      }

      final Map<String, dynamic>? userRow = await _supabase
          .from('users')
          .select('role')
          .eq('id', authUser.id)
          .maybeSingle();

      final Map<String, dynamic>? mitraRow = await _supabase
          .from('mitras')
          .select('is_active')
          .eq('id', authUser.id)
          .maybeSingle();

      final bool canUseMitraMode =
          mitraRow != null && mitraRow['is_active'] == true;
      final String databaseRole =
          (userRow?['role'] ?? 'user').toString().toLowerCase();

      final String? requestedMode = _normalizeMode(widget.initialRole);
      final String? savedMode =
          _normalizeMode(authUser.userMetadata?['active_mode']?.toString());

      String resolvedMode;
      if (requestedMode == 'mitra' && canUseMitraMode) {
        resolvedMode = 'mitra';
      } else if (requestedMode == 'customer') {
        resolvedMode = 'customer';
      } else if (savedMode == 'mitra' && canUseMitraMode) {
        resolvedMode = 'mitra';
      } else if (savedMode == 'customer') {
        resolvedMode = 'customer';
      } else if (databaseRole == 'mitra' && canUseMitraMode) {
        // Menjaga perilaku lama untuk akun mitra yang belum pernah memilih mode.
        resolvedMode = 'mitra';
      } else {
        resolvedMode = 'customer';
      }

      if (!mounted) return;
      setState(() {
        _canUseMitraMode = canUseMitraMode;
        _activeMode = resolvedMode;
        _isLoadingAccess = false;
      });
    } catch (error) {
      debugPrint('Error fetching account access in navbar: $error');
      if (mounted) {
        setState(() {
          _activeMode = 'customer';
          _canUseMitraMode = false;
          _isLoadingAccess = false;
        });
      }
    }
  }

  Future<void> _changeActiveMode(String requestedMode) async {
    final String? normalizedMode = _normalizeMode(requestedMode);
    if (normalizedMode == null || normalizedMode == _activeMode) return;

    if (normalizedMode == 'mitra' && !_canUseMitraMode) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Akun belum terdaftar sebagai mitra aktif.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _activeMode = normalizedMode;
      _currentIndex = 0;
      _dashboardRefreshTick++;
      _jobsRefreshTick++;
      _profileRefreshTick++;
    });

    // Simpan preferensi mode pada metadata Auth. Kegagalan penyimpanan tidak
    // membatalkan perubahan mode pada sesi yang sedang berjalan.
    try {
      await _supabase.auth.updateUser(
        UserAttributes(
          data: <String, dynamic>{'active_mode': normalizedMode},
        ),
      );
    } catch (error) {
      debugPrint('Mode aktif belum tersimpan ke metadata Auth: $error');
    }

    if (!mounted) return;
    final String label = normalizedMode == 'mitra' ? 'Mitra' : 'Customer';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sekarang menggunakan Mode $label.'),
        backgroundColor: const Color(0xFF4B613E),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _changePage(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 0) _dashboardRefreshTick++;
      if (index == 1) _jobsRefreshTick++;
      if (index == 3) _profileRefreshTick++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAccess) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFA6623)),
        ),
      );
    }

    final Widget activeDashboard = _activeMode == 'mitra'
        ? MitraDashboardPage(key: ValueKey(_dashboardRefreshTick))
        : DashboardPage(key: ValueKey(_dashboardRefreshTick));

    final List<Widget> pages = <Widget>[
      activeDashboard,
      JobPage(
        key: ValueKey('jobs-$_activeMode-$_jobsRefreshTick'),
        role: _activeMode,
      ),
      const ChatPage(),
      ProfilePage(
        key: ValueKey('profile-$_activeMode-$_profileRefreshTick'),
        activeMode: _activeMode,
        canUseMitraMode: _canUseMitraMode,
        onModeChanged: _changeActiveMode,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(index: _currentIndex, children: pages),
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
              children: <Widget>[
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
    final bool isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () => _changePage(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        constraints: const BoxConstraints(minWidth: 72),
        decoration: BoxDecoration(
          color: isActive ? _activePillBg : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
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
