import 'dart:async';

import 'package:ayosuruh/mitra_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat.dart';
import 'customer_dashboard.dart';
import 'job.dart';
import 'profile.dart';
import 'tutorial/ayos_tutorial.dart';
import 'notifications/notification_router.dart';
import 'services/notification_service.dart' as push_notifications;
import 'widgets/ayo_pressable.dart';
import 'widgets/ayo_snackbar.dart';

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
  final AyosTutorialAnchors _tutorialAnchors = AyosTutorialAnchors();

  int _currentIndex = 0;
  int _dashboardRefreshTick = 0;
  int _jobsRefreshTick = 0;
  int _profileRefreshTick = 0;

  String _activeMode = 'customer';
  bool _canUseMitraMode = false;
  bool _isLoadingAccess = true;
  StreamSubscription<Map<String, dynamic>>? _notificationTapSubscription;
  Map<String, dynamic>? _pendingNotificationTap;

  static const Color _navBgColor = Color(0xFFFAF7F5);
  static const Color _inactiveColor = Color(0xFF524538);
  static const Color _activeColor = Color(0xFF4B613E);
  static const Color _activePillBg = Color(0xFFF1F5ED);
  static const Color _borderColor = Color(0xFFF0ECE6);

  @override
  void initState() {
    super.initState();

    AyosTutorial.replayRequest.addListener(_handleTutorialReplayRequest);

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

    _fetchUserAccess();
  }

  @override
  void dispose() {
    AyosTutorial.replayRequest.removeListener(_handleTutorialReplayRequest);
    _notificationTapSubscription?.cancel();
    super.dispose();
  }

  void _handleTutorialReplayRequest() {
    final String? requestedMode = AyosTutorial.replayRequest.value;
    if (requestedMode == null || !mounted) return;
    AyosTutorial.replayRequest.value = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        AyosTutorial.show(
          context,
          mode: requestedMode,
          anchors: _tutorialAnchors,
          onSelectTab: _selectTutorialTab,
        ),
      );
    });
  }

  Future<void> _selectTutorialTab(int index) async {
    if (!mounted) return;
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
        if (index == 0) _dashboardRefreshTick++;
        if (index == 1) _jobsRefreshTick++;
        if (index == 3) _profileRefreshTick++;
      });
    }
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> data) async {
    if (_isLoadingAccess) {
      _pendingNotificationTap = Map<String, dynamic>.from(data);
      return;
    }

    if (!mounted) return;

    await NotificationRouter.openFromPushData(
      context,
      data,
      activeMode: _activeMode,
    );
  }

  void _flushPendingNotificationTap() {
    final Map<String, dynamic>? pending = _pendingNotificationTap;
    if (pending == null) return;
    _pendingNotificationTap = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_handleNotificationTap(pending));
      }
    });
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
      final bool openedFromNotification = _pendingNotificationTap != null;
      _flushPendingNotificationTap();
      if (!openedFromNotification) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            AyosTutorial.showIfNeeded(
              context,
              mode: resolvedMode,
              anchors: _tutorialAnchors,
              onSelectTab: _selectTutorialTab,
            );
          }
        });
      }
    } catch (error) {
      debugPrint('Error fetching account access in navbar: $error');
      if (mounted) {
        setState(() {
          _activeMode = 'customer';
          _canUseMitraMode = false;
          _isLoadingAccess = false;
        });
        _flushPendingNotificationTap();
      }
    }
  }

  Future<void> _changeActiveMode(String requestedMode) async {
    final String? normalizedMode = _normalizeMode(requestedMode);
    if (normalizedMode == null || normalizedMode == _activeMode) return;

    if (normalizedMode == 'mitra' && !_canUseMitraMode) {
      if (mounted) {
        AyoSnackBar.info(
          context,
          'Daftar sebagai Mitra terlebih dahulu untuk menerima pekerjaan.',
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
    AyoSnackBar.info(context, 'Sekarang menggunakan akun sebagai $label.');
    await AyosTutorial.showIfNeeded(
      context,
      mode: normalizedMode,
      anchors: _tutorialAnchors,
      onSelectTab: _selectTutorialTab,
    );
  }

  void _changePage(int index) {
    if (index == _currentIndex) return;
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
        ? MitraDashboardPage(
            key: ValueKey(_dashboardRefreshTick),
            tutorialAnchors: _tutorialAnchors,
          )
        : DashboardPage(
            key: ValueKey(_dashboardRefreshTick),
            tutorialAnchors: _tutorialAnchors,
          );

    final List<Widget> pages = <Widget>[
      activeDashboard,
      JobPage(
        key: ValueKey('jobs-$_activeMode-$_jobsRefreshTick'),
        role: _activeMode,
        tutorialKey: _tutorialAnchors.jobsOverview,
      ),
      ChatPage(
        tutorialKey: _tutorialAnchors.chatOverview,
        activeMode: _activeMode,
      ),
      ProfilePage(
        key: ValueKey('profile-$_activeMode-$_profileRefreshTick'),
        activeMode: _activeMode,
        canUseMitraMode: _canUseMitraMode,
        onModeChanged: _changeActiveMode,
        tutorialAnchors: _tutorialAnchors,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: HeroMode(
        enabled: false,
        child: pages[_currentIndex],
      ),
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
                  label: 'Beranda',
                  index: 0,
                  tutorialKey: _tutorialAnchors.navHome,
                ),
                _buildNavButton(
                  icon: Icons.work_outline_rounded,
                  activeIcon: Icons.work_rounded,
                  label: 'Pekerjaan',
                  index: 1,
                  tutorialKey: _tutorialAnchors.navJobs,
                ),
                _buildNavButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  activeIcon: Icons.chat_bubble_rounded,
                  label: 'Chat',
                  index: 2,
                  tutorialKey: _tutorialAnchors.navChat,
                ),
                _buildNavButton(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profil',
                  index: 3,
                  tutorialKey: _tutorialAnchors.navProfile,
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
    Key? tutorialKey,
  }) {
    final bool isActive = _currentIndex == index;

    return AyoPressable(
      key: tutorialKey,
      onTap: () => _changePage(index),
      haptic: true,
      pressedScale: 0.94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 210),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        constraints: const BoxConstraints(minWidth: 68),
        decoration: BoxDecoration(
          color: isActive ? _activePillBg : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedScale(
              scale: isActive ? 1.08 : 1,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              child: Icon(
                isActive ? activeIcon : icon,
                color: isActive ? _activeColor : _inactiveColor,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? _activeColor : _inactiveColor,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
