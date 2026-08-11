import 'dart:async';

import 'package:ayosuruh/mitra_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat.dart';
import 'customer_dashboard.dart';
import 'job.dart';
import 'profile.dart';
import 'tutorial/ayos_tutorial.dart';
import 'notifications/notification_router.dart';
import 'services/notification_service.dart' as push_notifications;
import 'widgets/ayo_snackbar.dart';
import 'chats/presence_service.dart';

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

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AyosTutorialAnchors _tutorialAnchors = AyosTutorialAnchors();
  final PresenceService _presenceService = PresenceService();
  late final AnimationController _navSplashController;

  int _navSplashIndex = 0;

  int _currentIndex = 0;
  int _navCacheEpoch = 0;
  final Set<int> _mountedTabs = <int>{0};

  String _activeMode = 'customer';
  bool _canUseMitraMode = false;
  bool _isLoadingAccess = true;
  StreamSubscription<Map<String, dynamic>>? _notificationTapSubscription;
  Map<String, dynamic>? _pendingNotificationTap;

  static const Color _navBgColor = Color(0xFFFAF7F5);
  static const Color _inactiveColor = Color(0xFF524538);
  static const Color _activeColor = Color(0xFF4B613E);
  static const Color _borderColor = Color(0xFFF0ECE6);

  @override
  void initState() {
    super.initState();
    _navSplashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );

    WidgetsBinding.instance.addObserver(this);
    unawaited(_presenceService.start());

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
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_presenceService.stop());
    AyosTutorial.replayRequest.removeListener(_handleTutorialReplayRequest);
    _notificationTapSubscription?.cancel();
    _navSplashController.dispose();
    super.dispose();
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_presenceService.start());
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_presenceService.stop());
    }
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
    final bool changed = _currentIndex != index;
    if (changed) {
      setState(() {
        _mountedTabs.add(index);
        _currentIndex = index;
      });
    }
    await WidgetsBinding.instance.endOfFrame;
    if (changed) {
      // Tunggu transisi navbar selesai agar spotlight menghitung posisi final,
      // bukan posisi page yang masih bergeser/fade.
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
    }
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
      unawaited(_prewarmNavigationTabs(_navCacheEpoch));
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
      _navCacheEpoch++;
      _mountedTabs
        ..clear()
        ..add(0);
    });
    unawaited(_prewarmNavigationTabs(_navCacheEpoch));

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

  Future<void> _prewarmNavigationTabs(int epoch) async {
    // Home tampil lebih dulu. Tab lain dimount bertahap di background supaya
    // perpindahan berikutnya tidak harus menunggu initState + fetch dari nol.
    for (final int index in <int>[1, 2, 3]) {
      await Future<void>.delayed(const Duration(milliseconds: 420));
      if (!mounted || epoch != _navCacheEpoch) return;
      if (_mountedTabs.contains(index)) continue;
      setState(() => _mountedTabs.add(index));
    }
  }

  void _playNavSplash(int index) {
    _navSplashIndex = index;
    _navSplashController
      ..stop()
      ..reset()
      ..forward();
  }

  void _changePage(int index) {
    _playNavSplash(index);
    HapticFeedback.selectionClick();
    if (index == _currentIndex) return;
    setState(() {
      _mountedTabs.add(index);
      _currentIndex = index;
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
            key: ValueKey('dashboard-$_activeMode-$_navCacheEpoch'),
            tutorialAnchors: _tutorialAnchors,
          )
        : DashboardPage(
            key: ValueKey('dashboard-$_activeMode-$_navCacheEpoch'),
            tutorialAnchors: _tutorialAnchors,
            onOpenChat: () => _changePage(2),
          );

    final List<Widget> pages = <Widget>[
      activeDashboard,
      JobPage(
        key: ValueKey('jobs-$_activeMode-$_navCacheEpoch'),
        role: _activeMode,
        tutorialKey: _tutorialAnchors.jobsOverview,
        tutorialPrimaryActionKey: _tutorialAnchors.jobsPrimaryAction,
      ),
      ChatPage(
        key: ValueKey('chat-$_activeMode-$_navCacheEpoch'),
        tutorialKey: _tutorialAnchors.chatOverview,
        firstActionTutorialKey: _tutorialAnchors.chatFirstAction,
        activeMode: _activeMode,
      ),
      ProfilePage(
        key: ValueKey('profile-$_activeMode-$_navCacheEpoch'),
        activeMode: _activeMode,
        canUseMitraMode: _canUseMitraMode,
        onModeChanged: _changeActiveMode,
        tutorialAnchors: _tutorialAnchors,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: List<Widget>.generate(4, (int index) {
          if (!_mountedTabs.contains(index)) {
            return const SizedBox.shrink();
          }

          final bool isActive = index == _currentIndex;
          final double hiddenDx = index < _currentIndex ? -0.035 : 0.035;

          return Positioned.fill(
            key: ValueKey<String>(
              'nav-slot-$_activeMode-$_navCacheEpoch-$index',
            ),
            child: IgnorePointer(
              ignoring: !isActive,
              child: ExcludeSemantics(
                excluding: !isActive,
                child: AnimatedOpacity(
                  opacity: isActive ? 1 : 0,
                  duration: const Duration(milliseconds: 230),
                  curve: Curves.easeOutCubic,
                  child: AnimatedSlide(
                    offset: isActive ? Offset.zero : Offset(hiddenDx, 0),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    child: HeroMode(
                      enabled: isActive,
                      child: TickerMode(
                        enabled: isActive,
                        child: pages[index],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
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
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                const int itemCount = 4;
                final double itemWidth = constraints.maxWidth / itemCount;

                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.hardEdge,
                  children: <Widget>[
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _navSplashController,
                          builder: (BuildContext context, Widget? child) {
                            return CustomPaint(
                              painter: _NavSplashPainter(
                                index: _navSplashIndex,
                                itemCount: itemCount,
                                itemWidth: itemWidth,
                                progress: _navSplashController.value,
                                color: const Color(0xFFF6990E),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Row(
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
                  ],
                );
              },
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

    return Expanded(
      child: KeyedSubtree(
        key: tutorialKey,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _changePage(index),
            borderRadius: BorderRadius.circular(18),
            splashFactory: InkRipple.splashFactory,
            splashColor: const Color(0xFFF6990E).withValues(alpha: 0.18),
            highlightColor: const Color(0xFFF6990E).withValues(alpha: 0.07),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    height: 24,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 190),
                        reverseDuration: const Duration(milliseconds: 160),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.86, end: 1).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Icon(
                          isActive ? activeIcon : icon,
                          key: ValueKey<bool>(isActive),
                          color: isActive ? _activeColor : _inactiveColor,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 190),
                    curve: Curves.easeOutCubic,
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
          ),
        ),
      ),
    );
  }

}

class _NavSplashPainter extends CustomPainter {
  const _NavSplashPainter({
    required this.index,
    required this.itemCount,
    required this.itemWidth,
    required this.progress,
    required this.color,
  });

  final int index;
  final int itemCount;
  final double itemWidth;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1 || itemCount <= 0) return;

    final double expansion = Curves.easeOutCubic.transform(progress);
    final double fade = progress < 0.26
        ? Curves.easeOut.transform(progress / 0.26)
        : Curves.easeIn.transform((1 - progress) / 0.74);

    final double maxWidth =
        (itemWidth * 2.55).clamp(itemWidth, size.width).toDouble();
    final double splashWidth =
        itemWidth * 0.42 + (maxWidth - itemWidth * 0.42) * expansion;
    final double centerX = itemWidth * (index + 0.5);

    double left = centerX - splashWidth / 2;
    double right = centerX + splashWidth / 2;

    // Edge tabs tetap mendapat splash selebar tab tengah. Area yang seharusnya
    // keluar layar dialihkan ke arah dalam, sementara peak tetap di bawah icon.
    if (left < 0) {
      right -= left;
      left = 0;
    }
    if (right > size.width) {
      final double overflow = right - size.width;
      left -= overflow;
      right = size.width;
    }
    left = left.clamp(0.0, size.width).toDouble();
    right = right.clamp(0.0, size.width).toDouble();

    final Rect rect = Rect.fromLTRB(left, 0, right, size.height);
    final double peak =
        ((centerX - rect.left) / rect.width).clamp(0.08, 0.92).toDouble();
    final double shoulder =
        (0.18 + 0.10 * expansion).clamp(0.16, 0.30).toDouble();
    final double leftShoulder =
        (peak - shoulder).clamp(0.0, peak).toDouble();
    final double rightShoulder =
        (peak + shoulder).clamp(peak, 1.0).toDouble();
    // Splash sengaja sedikit lebih tebal daripada ripple agar gelombang
    // gradasinya terbaca jelas, tetapi tetap hilang lembut di ujung animasi.
    final double alpha = 0.32 * fade;

    final Paint paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          color.withValues(alpha: 0),
          color.withValues(alpha: alpha * 0.32),
          color.withValues(alpha: alpha),
          color.withValues(alpha: alpha * 0.32),
          color.withValues(alpha: 0),
        ],
        stops: <double>[
          0,
          leftShoulder,
          peak,
          rightShoulder,
          1,
        ],
      ).createShader(rect);

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _NavSplashPainter oldDelegate) {
    return oldDelegate.index != index ||
        oldDelegate.itemWidth != itemWidth ||
        oldDelegate.progress != progress ||
        oldDelegate.color != color;
  }
}
