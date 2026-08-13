import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/ayo_theme.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';

/// Anchor yang dipasang pada UI asli Ayo Suruh.
///
/// Tutorial tidak membuat mockup halaman. Spotlight selalu menunjuk widget yang
/// benar-benar sedang digunakan user di Beranda, Pekerjaan, Chat, dan Profil.
class AyosTutorialAnchors {
  final GlobalKey homeHeader = GlobalKey(debugLabel: 'tutorial-home-header');
  final GlobalKey homeSearchOrIncome = GlobalKey(
    debugLabel: 'tutorial-home-search-income',
  );
  final GlobalKey homePromoOrService = GlobalKey(
    debugLabel: 'tutorial-home-promo-service',
  );
  final GlobalKey homeTrivia = GlobalKey(debugLabel: 'tutorial-home-trivia');
  final GlobalKey homeCategoriesOrActive = GlobalKey(
    debugLabel: 'tutorial-home-categories-active',
  );
  final GlobalKey homePrimaryActionOrAvailable = GlobalKey(
    debugLabel: 'tutorial-home-primary-available',
  );

  final GlobalKey jobsOverview = GlobalKey(
    debugLabel: 'tutorial-jobs-overview',
  );
  final GlobalKey jobsPrimaryAction = GlobalKey(
    debugLabel: 'tutorial-jobs-primary-action',
  );
  final GlobalKey chatOverview = GlobalKey(
    debugLabel: 'tutorial-chat-overview',
  );
  final GlobalKey chatFirstAction = GlobalKey(
    debugLabel: 'tutorial-chat-first-action',
  );
  final GlobalKey profileHeader = GlobalKey(
    debugLabel: 'tutorial-profile-header',
  );
  final GlobalKey profileMode = GlobalKey(debugLabel: 'tutorial-profile-mode');
  final GlobalKey profileFinance = GlobalKey(
    debugLabel: 'tutorial-profile-finance',
  );

  final GlobalKey navHome = GlobalKey(debugLabel: 'tutorial-nav-home');
  final GlobalKey navJobs = GlobalKey(debugLabel: 'tutorial-nav-jobs');
  final GlobalKey navChat = GlobalKey(debugLabel: 'tutorial-nav-chat');
  final GlobalKey navProfile = GlobalKey(debugLabel: 'tutorial-nav-profile');
}

class AyosTutorial {
  AyosTutorial._();

  // Versi baru agar tester yang pernah melihat tutorial card v1 tetap dapat
  // mencoba walkthrough interaktif sekali. Setelah itu tersimpan per mode.
  static const String _version = 'v3_release';

  /// Dipakai menu Pengaturan untuk meminta MainNavigation memutar tutorial
  /// lagi setelah route Pengaturan ditutup.
  static final ValueNotifier<String?> replayRequest = ValueNotifier<String?>(
    null,
  );

  static String _normalizedMode(String mode) =>
      mode.trim().toLowerCase() == 'mitra' ? 'mitra' : 'customer';

  static String _seenKey(String mode) {
    final String userId =
        Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    return 'ayos_tutorial_${userId}_${_normalizedMode(mode)}_$_version';
  }

  static Future<bool> hasSeen(String mode) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_seenKey(mode)) ?? false;
  }

  static Future<void> markSeen(String mode) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_seenKey(mode), true);
  }

  static Future<void> reset(String mode) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.remove(_seenKey(mode));
  }

  static Future<void> showIfNeeded(
    BuildContext context, {
    required String mode,
    required AyosTutorialAnchors anchors,
    required Future<void> Function(int index) onSelectTab,
  }) async {
    if (await hasSeen(mode) || !context.mounted) return;
    await show(context, mode: mode, anchors: anchors, onSelectTab: onSelectTab);
  }

  /// Jika dipanggil dari MainNavigation, tutorial langsung berjalan di UI asli.
  /// Jika dipanggil dari halaman turunan seperti Pengaturan, route dikembalikan
  /// ke shell utama dan MainNavigation menerima [replayRequest].
  static Future<void> show(
    BuildContext context, {
    required String mode,
    AyosTutorialAnchors? anchors,
    Future<void> Function(int index)? onSelectTab,
  }) async {
    final String normalized = _normalizedMode(mode);

    if (anchors == null || onSelectTab == null) {
      replayRequest.value = normalized;
      if (context.mounted) {
        Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
      }
      return;
    }

    if (!context.mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder:
          (
            BuildContext dialogContext,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return _AyosInteractiveTutorial(
              mode: normalized,
              anchors: anchors,
              onSelectTab: onSelectTab,
            );
          },
      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            return FadeTransition(opacity: animation, child: child);
          },
    );
    await markSeen(normalized);
  }
}

class _TutorialStep {
  const _TutorialStep({
    required this.target,
    required this.tabIndex,
    required this.title,
    required this.body,
    required this.assetPath,
    this.preferAbove = false,
  });

  final GlobalKey target;
  final int tabIndex;
  final String title;
  final String body;
  final String assetPath;
  final bool preferAbove;
}

class _AyosInteractiveTutorial extends StatefulWidget {
  const _AyosInteractiveTutorial({
    required this.mode,
    required this.anchors,
    required this.onSelectTab,
  });

  final String mode;
  final AyosTutorialAnchors anchors;
  final Future<void> Function(int index) onSelectTab;

  @override
  State<_AyosInteractiveTutorial> createState() =>
      _AyosInteractiveTutorialState();
}

class _AyosInteractiveTutorialState extends State<_AyosInteractiveTutorial> {
  static const Color _orange = Color(0xFFF6990E);
  static Color get _brown => AyoAdaptiveColors.brown;

  int _index = 0;
  Rect? _targetRect;
  bool _preparing = true;
  late final List<_TutorialStep> _steps;

  @override
  void initState() {
    super.initState();
    _steps = widget.mode == 'mitra' ? _mitraSteps() : _customerSteps();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_prepareCurrentStep());
    });
  }

  List<_TutorialStep> _customerSteps() => <_TutorialStep>[
    _TutorialStep(
      target: widget.anchors.homeHeader,
      tabIndex: 0,
      title: 'Kenalan dulu sama Beranda 👋',
      body:
          'Di sini ada sapaan dan alamat utama akunmu. Tenang, lokasi tiap pekerjaan tetap bisa kamu atur sendiri saat bikin job.',
      assetPath: 'assets/images/ayos/ayos_hello.png',
    ),
    _TutorialStep(
      target: widget.anchors.homeSearchOrIncome,
      tabIndex: 0,
      title: 'Butuh jasa? Cari dari sini',
      body:
          'Ketik yang lagi kamu butuhin, lalu pilih jasa Mitra yang paling cocok. Nggak perlu muter-muter cari dari menu lain.',
      assetPath: 'assets/images/ayos/ayos_play_phone.png',
    ),
    _TutorialStep(
      target: widget.anchors.homePromoOrService,
      tabIndex: 0,
      title: 'Banner-nya bisa ditekan',
      body:
          'Selain buat info, banner juga jadi pintasan ke fitur tertentu. Kalau penasaran, tinggal tap aja.',
      assetPath: 'assets/images/ayos/ayos_announce.png',
    ),
    _TutorialStep(
      target: widget.anchors.homeTrivia,
      tabIndex: 0,
      title: 'Ada bacaan receh juga',
      body:
          'Bagian Sekilas bakal muterin trivia, fun fact, sampai info yang lagi rame. Lumayan buat nemenin scroll.',
      assetPath: 'assets/images/ayos/ayos_idea.png',
    ),
    _TutorialStep(
      target: widget.anchors.homeCategoriesOrActive,
      tabIndex: 0,
      title: 'Kalau udah tahu kategorinya, gas',
      body:
          'Pilih kategori biar pencarian jasa lebih cepat. Geser kalau mau lihat pilihan lainnya.',
      assetPath: 'assets/images/ayos/ayos_pointing_left.png',
    ),
    _TutorialStep(
      target: widget.anchors.homePrimaryActionOrAvailable,
      tabIndex: 0,
      title: 'Jasa Mitra langsung nongol di Home',
      body:
          'Geser kartu jasanya, cek harga dan rating, lalu tap kalau mau lihat detail atau profil Mitranya.',
      assetPath: 'assets/images/ayos/ayos_board_task.png',
      preferAbove: true,
    ),
    _TutorialStep(
      target: widget.anchors.navJobs,
      tabIndex: 0,
      title: 'Urusan pekerjaan ada di sini',
      body:
          'Masuk ke Pekerjaan kalau mau bikin pekerjaan baru, cek yang masih aktif, lihat peluang, atau buka riwayat.',
      assetPath: 'assets/images/ayos/ayos_pointing_left.png',
      preferAbove: true,
    ),
    _TutorialStep(
      target: widget.anchors.jobsOverview,
      tabIndex: 1,
      title: 'Aktif, Peluang, sama Riwayat',
      body:
          'Aktif buat job yang lagi jalan, Peluang buat lihat pekerjaan terbuka, dan Riwayat buat yang sudah selesai atau dibatalkan.',
      assetPath: 'assets/images/ayos/ayos_board_task.png',
    ),
    _TutorialStep(
      target: widget.anchors.jobsPrimaryAction,
      tabIndex: 1,
      title: 'Mau nyuruh? Mulainya dari sini',
      body:
          'Tekan Buat Pekerjaan, isi kebutuhanmu, tentukan lokasi dan detailnya, lalu tunggu penawaran dari Mitra.',
      assetPath: 'assets/images/ayos/ayos_run.png',
      preferAbove: true,
    ),
    _TutorialStep(
      target: widget.anchors.navChat,
      tabIndex: 1,
      title: 'Kalau perlu ngobrol, buka Chat',
      body:
          'Semua percakapan sama Mitra bakal ngumpul di tab ini, jadi koordinasi nggak tercecer.',
      assetPath: 'assets/images/ayos/ayos_play_phone.png',
      preferAbove: true,
    ),
    _TutorialStep(
      target: widget.anchors.chatOverview,
      tabIndex: 2,
      title: 'Cari chat tanpa scroll panjang',
      body:
          'Kalau percakapanmu udah banyak, cari aja pakai nama orang atau judul pekerjaannya.',
      assetPath: 'assets/images/ayos/ayos_play_phone.png',
    ),
    _TutorialStep(
      target: widget.anchors.chatFirstAction,
      tabIndex: 2,
      title: 'Belum pernah chat? Mulai dari jasa',
      body:
          'Tap Mulai Chat Pertamamu. Kamu bakal dibawa ke katalog jasa Mitra, lalu bisa mulai ngobrol dari jasa yang dipilih.',
      assetPath: 'assets/images/ayos/ayos_play_phone.png',
      preferAbove: true,
    ),
    _TutorialStep(
      target: widget.anchors.navProfile,
      tabIndex: 2,
      title: 'Terakhir, ada Profil',
      body:
          'Biodata, peran akun, saldo, bantuan, keamanan, dan pengaturan semuanya bisa kamu temuin dari sini.',
      assetPath: 'assets/images/ayos/ayos_idea.png',
      preferAbove: true,
    ),
    _TutorialStep(
      target: widget.anchors.profileHeader,
      tabIndex: 3,
      title: 'Ini pusat akunmu',
      body:
          'Mau ganti foto, cek data akun, atau lanjut ke pengaturan? Mulainya dari halaman Profil.',
      assetPath: 'assets/images/ayos/ayos_idea.png',
    ),
    _TutorialStep(
      target: widget.anchors.profileMode,
      tabIndex: 3,
      title: 'Satu akun bisa punya dua peran',
      body:
          'Kalau akunmu sudah jadi Mitra, kamu bisa pindah Customer ↔ Mitra kapan aja tanpa bikin akun baru.',
      assetPath: 'assets/images/ayos/ayos_run.png',
    ),
    _TutorialStep(
      target: widget.anchors.profileFinance,
      tabIndex: 3,
      title: 'AyoPay & transaksi ada di sini',
      body:
          'Cek saldo AyoPay dan riwayat pembayaran dari Profil. Pengaturan keamanan akun tetap ada di menu Pengaturan.',
      assetPath: 'assets/images/ayos/ayos_earnings.png',
      preferAbove: true,
    ),
  ];

  List<_TutorialStep> _mitraSteps() => <_TutorialStep>[
    _TutorialStep(
      target: widget.anchors.homeHeader,
      tabIndex: 0,
      title: 'Sekarang kamu lagi di mode Mitra.',
      body:
          'Di mode ini fokusnya beda: cari pekerjaan, kelola jasa, pantau progres, sampai urus penghasilan.',
      assetPath: 'assets/images/ayos/ayos_hello.png',
    ),
    _TutorialStep(
      target: widget.anchors.homeSearchOrIncome,
      tabIndex: 0,
      title: 'Penghasilanmu kelihatan dari sini',
      body:
          'Ringkasan ini bantu kamu lihat hasil kerja. Detail saldo tersedia, pending, atau ditahan bisa dicek dari Dompet Mitra.',
      assetPath: 'assets/images/ayos/ayos_earnings.png',
    ),
    _TutorialStep(
      target: widget.anchors.homePromoOrService,
      tabIndex: 0,
      title: 'Jasa Saya itu etalase kamu',
      body:
          'Upload jasa yang kamu tawarkan lengkap dengan foto, harga, dan deskripsi biar Customer gampang nemuin kamu.',
      assetPath: 'assets/images/ayos/ayos_idea.png',
    ),
    _TutorialStep(
      target: widget.anchors.homeCategoriesOrActive,
      tabIndex: 0,
      title: 'Yang lagi dikerjain nongol di sini',
      body:
          'Begitu penawaranmu diterima, pekerjaan aktif bisa dipantau dari Home dan dilanjutkan lewat detail pekerjaan.',
      assetPath: 'assets/images/ayos/ayos_board_task.png',
    ),
    _TutorialStep(
      target: widget.anchors.homePrimaryActionOrAvailable,
      tabIndex: 0,
      title: 'Ada pekerjaan yang bisa kamu ambil',
      body:
          'Cek pekerjaan terbaru yang tersedia. Kalau cocok sama keahlian dan lokasimu, buka detail lalu kirim penawaran.',
      assetPath: 'assets/images/ayos/ayos_run.png',
      preferAbove: true,
    ),
    _TutorialStep(
      target: widget.anchors.navJobs,
      tabIndex: 0,
      title: 'Daftar lengkapnya ada di Pekerjaan',
      body:
          'Di sini kamu bisa pindah antara pekerjaan Tersedia, Pengajuan yang sudah dikirim, dan pekerjaan Aktif.',
      assetPath: 'assets/images/ayos/ayos_pointing_left.png',
      preferAbove: true,
    ),
    _TutorialStep(
      target: widget.anchors.jobsOverview,
      tabIndex: 1,
      title: 'Tersedia, Pengajuan, dan Aktif',
      body:
          'Tersedia buat cari pekerjaan, Pengajuan buat cek status penawaran, dan Aktif buat pekerjaan yang sudah dipercayakan ke kamu.',
      assetPath: 'assets/images/ayos/ayos_board_task.png',
    ),
    _TutorialStep(
      target: widget.anchors.navChat,
      tabIndex: 1,
      title: 'Koordinasinya lewat Chat',
      body:
          'Kalau sudah terhubung sama Customer, pakai Chat buat ngobrol soal kebutuhan, lokasi, dan progres kerja.',
      assetPath: 'assets/images/ayos/ayos_play_phone.png',
      preferAbove: true,
    ),
    _TutorialStep(
      target: widget.anchors.chatOverview,
      tabIndex: 2,
      title: 'Cari percakapan dengan cepat',
      body:
          'Gunakan kolom pencarian kalau chat sudah ramai. Bisa cari berdasarkan nama Customer atau judul pekerjaan.',
      assetPath: 'assets/images/ayos/ayos_play_phone.png',
    ),
    _TutorialStep(
      target: widget.anchors.navProfile,
      tabIndex: 2,
      title: 'Dompet dan akun ada di Profil',
      body:
          'Mau cairin penghasilan, atur rekening, cek riwayat, atau balik jadi Customer? Semuanya mulai dari sini.',
      assetPath: 'assets/images/ayos/ayos_idea.png',
      preferAbove: true,
    ),
    _TutorialStep(
      target: widget.anchors.profileHeader,
      tabIndex: 3,
      title: 'Profil Mitra kamu',
      body:
          'Di sini ada identitas akun dan informasi Mitra yang kamu pakai selama menjalankan pekerjaan.',
      assetPath: 'assets/images/ayos/ayos_idea.png',
    ),
    _TutorialStep(
      target: widget.anchors.profileMode,
      tabIndex: 3,
      title: 'Mau balik jadi Customer? Bisa',
      body:
          'Pindah peran nggak bikin data Mitramu hilang. Tinggal switch lagi kalau nanti mau cari pekerjaan.',
      assetPath: 'assets/images/ayos/ayos_run.png',
    ),
    _TutorialStep(
      target: widget.anchors.profileFinance,
      tabIndex: 3,
      title: 'Penghasilan dan pencairan ada di sini',
      body:
          'Saldo yang sudah tersedia bisa dicairkan ke rekening. PIN AyoPay 6 digit dipakai buat melindungi aksi sensitif seperti pencairan dan perubahan rekening.',
      assetPath: 'assets/images/ayos/ayos_earnings.png',
      preferAbove: true,
    ),
  ];

  Future<BuildContext?> _waitForTarget(GlobalKey target) async {
    for (int attempt = 0; attempt < 30; attempt++) {
      if (!mounted) return null;
      final BuildContext? targetContext = target.currentContext;
      if (targetContext != null) return targetContext;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await WidgetsBinding.instance.endOfFrame;
    }
    return null;
  }

  Rect? _readTargetRect(GlobalKey target) {
    final BuildContext? targetContext = target.currentContext;
    if (targetContext == null || !targetContext.mounted) return null;

    final RenderObject? object = targetContext.findRenderObject();
    if (object is! RenderBox || !object.hasSize || !object.attached) return null;
    if (object.size.width <= 1 || object.size.height <= 1) return null;

    final Offset topLeft = object.localToGlobal(Offset.zero);
    return topLeft & object.size;
  }

  bool _rectIsStable(Rect previous, Rect current) {
    const double tolerance = 1.25;
    return (previous.left - current.left).abs() <= tolerance &&
        (previous.top - current.top).abs() <= tolerance &&
        (previous.width - current.width).abs() <= tolerance &&
        (previous.height - current.height).abs() <= tolerance;
  }

  /// First-login tutorial can start while the Home route, async profile data,
  /// and the first ListView layout are still settling. Sampling a single rect
  /// in that window leaves the spotlight at an obsolete position. Wait until
  /// the real widget has stayed in the same global rect for several frames.
  Future<Rect?> _waitForStableTargetRect(GlobalKey target) async {
    Rect? previous;
    int stableSamples = 0;

    for (int attempt = 0; attempt < 36; attempt++) {
      if (!mounted) return null;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return null;

      final Rect? current = _readTargetRect(target);
      if (current != null) {
        if (previous != null && _rectIsStable(previous, current)) {
          stableSamples++;
          if (stableSamples >= 3) return current;
        } else {
          stableSamples = 0;
        }
        previous = current;
      } else {
        previous = null;
        stableSamples = 0;
      }

      await Future<void>.delayed(const Duration(milliseconds: 45));
    }

    return _readTargetRect(target);
  }

  Future<void> _prepareCurrentStep() async {
    if (!mounted || _steps.isEmpty) return;
    setState(() => _preparing = true);

    final _TutorialStep step = _steps[_index];
    await widget.onSelectTab(step.tabIndex);
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;

    // Dashboard/Profile memuat data secara async. Tunggu anchor UI asli
    // tersedia supaya spotlight tidak lompat hanya karena data belum selesai.
    final BuildContext? visibleTarget = await _waitForTarget(step.target);
    if (!mounted) return;

    if (visibleTarget == null) {
      await _skipUnavailableStep();
      return;
    }
    if (!visibleTarget.mounted) {
      await _skipUnavailableStep();
      return;
    }

    // Beberapa target berada di bawah fold. Scroll halaman asli dulu, lalu
    // ambil context baru setelah animasi selesai agar tidak memakai BuildContext
    // yang melewati async gap.
    final bool keepAtTop =
        identical(step.target, widget.anchors.homeHeader) ||
        identical(step.target, widget.anchors.homeSearchOrIncome);
    try {
      // Home can retain a small scroll offset after normal browsing. For the
      // first tutorial anchors, reset the owning Scrollable to its true top
      // before calculating the spotlight so the name + primary location are
      // always inside the highlighted area.
      if (keepAtTop) {
        final ScrollableState? scrollable = Scrollable.maybeOf(visibleTarget);
        if (scrollable != null && scrollable.position.hasPixels) {
          // Keep the first Home anchors at the ListView's real top. Calling
          // ensureVisible afterwards with a near-zero alignment would scroll
          // the greeting back underneath the fixed crystal AppBar.
          scrollable.position.jumpTo(scrollable.position.minScrollExtent);
          if (!mounted) return;
          await WidgetsBinding.instance.endOfFrame;
        }
      }

      final BuildContext? refreshedTarget = step.target.currentContext;
      if (refreshedTarget == null || !refreshedTarget.mounted) return;

      if (!keepAtTop) {
        await Scrollable.ensureVisible(
          refreshedTarget,
          alignment: 0.34,
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
          duration: const Duration(milliseconds: 330),
          curve: Curves.easeOutCubic,
        );
      }
    } catch (_) {
      // Target di luar Scrollable (mis. FAB/navbar) tetap bisa disorot.
    }

    if (!mounted) return;

    // Do not freeze the spotlight from a transitional frame. This is most
    // important on the automatic first-login tutorial, where Home may still be
    // completing its route animation/profile fetch even though the anchor
    // already exists.
    final Rect? stableRect = await _waitForStableTargetRect(step.target);
    if (!mounted) return;
    if (stableRect == null) {
      await _skipUnavailableStep();
      return;
    }

    setState(() {
      _targetRect = stableRect.inflate(6);
      _preparing = false;
    });
  }

  Future<void> _skipUnavailableStep() async {
    if (!mounted) return;
    if (_index < _steps.length - 1) {
      _index++;
      await _prepareCurrentStep();
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _next() async {
    if (_index >= _steps.length - 1) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() {
      _index++;
      _targetRect = null;
    });
    await _prepareCurrentStep();
  }

  void _skip() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    final Rect? target = _targetRect;
    final _TutorialStep step = _steps[_index];

    final double cardWidth = (screen.width - 32).clamp(0, 390).toDouble();
    const double cardEstimatedHeight = 230;
    final bool placeAbove =
        step.preferAbove ||
        (target != null && target.center.dy > screen.height * 0.55);

    double? top;
    double? bottom;
    if (target != null) {
      if (placeAbove) {
        bottom = (screen.height - target.top + 14)
            .clamp(88, screen.height - cardEstimatedHeight - 12)
            .toDouble();
      } else {
        top = (target.bottom + 14)
            .clamp(18, screen.height - cardEstimatedHeight - 88)
            .toDouble();
      }
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          CustomPaint(painter: _SpotlightPainter(targetRect: target)),
          if (_preparing || target == null)
            const Center(child: CircularProgressIndicator(color: _orange))
          else
            Positioned(
              left: (screen.width - cardWidth) / 2,
              width: cardWidth,
              top: top,
              bottom: bottom,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.97,
                        end: 1,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<int>(_index),
                  child: _buildCoachCard(step),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCoachCard(_TutorialStep step) {
    final bool last = _index == _steps.length - 1;
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color cardColor = dark ? const Color(0xFF241E1B) : const Color(0xFFFFFBF7);
    final Color borderColor = dark ? const Color(0xFF5C493D) : const Color(0xFFFFDCA5);
    final Color titleColor = dark ? const Color(0xFFFFE6D2) : _brown;
    final Color bodyColor = dark ? const Color(0xFFD8C9C0) : const Color(0xFF625750);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.42 : 0.20),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF3A2C24) : const Color(0xFFFFE8C5),
                  borderRadius: BorderRadius.circular(22),
                ),
                clipBehavior: Clip.antiAlias,
                child: Transform.scale(
                  scale: 1.28,
                  child: Image.asset(
                    step.assetPath,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.directions_run_rounded,
                      color: _orange,
                      size: 42,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AyoText(
                      widget.mode == 'mitra'
                          ? 'AYOS · Mode Mitra'
                          : 'AYOS · Kenalan Yuk',
                      style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.7,
                        fontWeight: FontWeight.w800,
                        color: _orange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AyoText(
                      step.title,
                      style: AyoTypography.accent(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                        height: 1.12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF332B27) : const Color(0xFFF4EEE8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: AyoText(
                  '${_index + 1}/${_steps.length}',
                  style: TextStyle(
                    color: dark ? const Color(0xFFC8B8AF) : const Color(0xFF74665D),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AyoText(
            step.body,
            style: TextStyle(
              color: bodyColor,
              fontSize: 12,
              height: 1.48,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              TextButton(
                onPressed: _skip,
                child: AyoText(
                  'Lewati',
                  style: TextStyle(
                    color: dark ? const Color(0xFFB9AAA2) : const Color(0xFF81766F),
                  ),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _next,
                style: FilledButton.styleFrom(
                  backgroundColor: dark ? _orange : _brown,
                  foregroundColor: dark ? const Color(0xFF2F221A) : Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                ),
                icon: Icon(
                  last ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  size: 17,
                ),
                label: AyoText(last ? 'Sip, ngerti!' : 'Lanjut'),
              ),
            ],
          ),
        ],
      ),
    );
  }

}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({required this.targetRect});

  final Rect? targetRect;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint overlay = Paint()..color = const Color(0xB8000000);
    final Path path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);

    final Rect? target = targetRect;
    if (target != null) {
      path.addRRect(RRect.fromRectAndRadius(target, const Radius.circular(18)));
    }
    canvas.drawPath(path, overlay);

    if (target != null) {
      final Paint border = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFFFC45C);
      canvas.drawRRect(
        RRect.fromRectAndRadius(target, const Radius.circular(18)),
        border,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.targetRect != targetRect;
}
