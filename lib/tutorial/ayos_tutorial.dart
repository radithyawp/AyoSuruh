import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/ayo_theme.dart';

/// Anchor yang dipasang pada UI asli Ayo Suruh.
///
/// Tutorial tidak membuat mockup halaman. Spotlight selalu menunjuk widget yang
/// benar-benar sedang digunakan user di Home, Jobs, Chat, dan Profile.
class AyosTutorialAnchors {
  final GlobalKey homeHeader = GlobalKey(debugLabel: 'tutorial-home-header');
  final GlobalKey homeSearchOrIncome =
      GlobalKey(debugLabel: 'tutorial-home-search-income');
  final GlobalKey homePromoOrService =
      GlobalKey(debugLabel: 'tutorial-home-promo-service');
  final GlobalKey homeCategoriesOrActive =
      GlobalKey(debugLabel: 'tutorial-home-categories-active');
  final GlobalKey homePrimaryActionOrAvailable =
      GlobalKey(debugLabel: 'tutorial-home-primary-available');

  final GlobalKey jobsOverview =
      GlobalKey(debugLabel: 'tutorial-jobs-overview');
  final GlobalKey chatOverview =
      GlobalKey(debugLabel: 'tutorial-chat-overview');
  final GlobalKey profileHeader =
      GlobalKey(debugLabel: 'tutorial-profile-header');
  final GlobalKey profileMode =
      GlobalKey(debugLabel: 'tutorial-profile-mode');
  final GlobalKey profileFinance =
      GlobalKey(debugLabel: 'tutorial-profile-finance');

  final GlobalKey navHome = GlobalKey(debugLabel: 'tutorial-nav-home');
  final GlobalKey navJobs = GlobalKey(debugLabel: 'tutorial-nav-jobs');
  final GlobalKey navChat = GlobalKey(debugLabel: 'tutorial-nav-chat');
  final GlobalKey navProfile = GlobalKey(debugLabel: 'tutorial-nav-profile');
}

class AyosTutorial {
  AyosTutorial._();

  // Versi baru agar tester yang pernah melihat tutorial card v1 tetap dapat
  // mencoba walkthrough interaktif sekali. Setelah itu tersimpan per mode.
  static const String _version = 'v2_interactive';

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
    await show(
      context,
      mode: mode,
      anchors: anchors,
      onSelectTab: onSelectTab,
    );
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
      pageBuilder: (
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
      transitionBuilder: (
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
  static const Color _brown = Color(0xFF6E481F);

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
          title: 'Halo! AYOS akan nemenin kamu 👋',
          body:
              'Di bagian ini kamu bisa melihat akun dan alamat utama. Alamat Home mengikuti profil, sedangkan lokasi tiap pekerjaan tetap bisa berbeda.',
          assetPath: 'assets/images/ayos/ayos_hello.png',
        ),
        _TutorialStep(
          target: widget.anchors.homeSearchOrIncome,
          tabIndex: 0,
          title: 'Cari bantuan tanpa muter-muter',
          body:
              'Ketik layanan yang kamu butuhkan. Dari katalog, kamu juga bisa menemukan jasa yang dipublikasikan langsung oleh Mitra.',
          assetPath: 'assets/images/ayos/ayos_play_phone.png',
        ),
        _TutorialStep(
          target: widget.anchors.homePromoOrService,
          tabIndex: 0,
          title: 'Banner bukan cuma pajangan',
          body:
              'Promo di Home bisa ditekan dan langsung membuka pembuatan pekerjaan dengan kategori yang relevan.',
          assetPath: 'assets/images/ayos/ayos_announce.png',
        ),
        _TutorialStep(
          target: widget.anchors.homeCategoriesOrActive,
          tabIndex: 0,
          title: 'Pilih kategori layanan',
          body:
              'Gunakan kategori untuk mempercepat pembuatan pekerjaan. Tekan “Lihat semua” untuk membuka katalog lengkap.',
          assetPath: 'assets/images/ayos/ayos_pointing_left.png',
        ),
        _TutorialStep(
          target: widget.anchors.homePrimaryActionOrAvailable,
          tabIndex: 0,
          title: 'Buat kebutuhanmu dari sini',
          body:
              'Tekan Buat Pekerjaan untuk menulis kebutuhan, memasang foto, menentukan lokasi, jadwal, dan budget sebelum menerima penawaran Mitra.',
          assetPath: 'assets/images/ayos/ayos_board_task.png',
          preferAbove: true,
        ),
        _TutorialStep(
          target: widget.anchors.navJobs,
          tabIndex: 0,
          title: 'Pindah ke Jobs dari navbar',
          body:
              'Navbar selalu siap di bagian bawah. Jobs adalah jalan cepat untuk kembali ke pekerjaan aktif maupun riwayat tanpa menumpuk halaman baru.',
          assetPath: 'assets/images/ayos/ayos_pointing_left.png',
          preferAbove: true,
        ),
        _TutorialStep(
          target: widget.anchors.jobsOverview,
          tabIndex: 1,
          title: 'Jobs = pusat pekerjaanmu',
          body:
              'Pantau pekerjaan aktif dan riwayat di sini. Penawaran, progres, konfirmasi selesai, dan rating semuanya berawal dari pekerjaan terkait.',
          assetPath: 'assets/images/ayos/ayos_board_task.png',
        ),
        _TutorialStep(
          target: widget.anchors.navChat,
          tabIndex: 1,
          title: 'Berikutnya: Chat',
          body:
              'Kalau perlu koordinasi, kamu tidak perlu mencari dari awal. Tab Chat mengumpulkan percakapan yang sudah terkait dengan pekerjaan.',
          assetPath: 'assets/images/ayos/ayos_play_phone.png',
          preferAbove: true,
        ),
        _TutorialStep(
          target: widget.anchors.chatOverview,
          tabIndex: 2,
          title: 'Koordinasi lewat Chat',
          body:
              'Setelah Customer memilih Mitra, percakapan terkait pekerjaan akan muncul di sini. Kamu bisa mencari chat berdasarkan nama atau pekerjaan.',
          assetPath: 'assets/images/ayos/ayos_play_phone.png',
        ),
        _TutorialStep(
          target: widget.anchors.navProfile,
          tabIndex: 2,
          title: 'Terakhir, buka Profile',
          body:
              'Profile bukan sekadar biodata. Dari tab ini kamu mengelola peran akun, keuangan, bantuan, keamanan, dan pengaturan aplikasi.',
          assetPath: 'assets/images/ayos/ayos_idea.png',
          preferAbove: true,
        ),
        _TutorialStep(
          target: widget.anchors.profileHeader,
          tabIndex: 3,
          title: 'Profile adalah pusat akunmu',
          body:
              'Kelola identitas, foto profil, bantuan, pengaturan, keamanan, dan fitur akun dari halaman Profile.',
          assetPath: 'assets/images/ayos/ayos_idea.png',
        ),
        _TutorialStep(
          target: widget.anchors.profileMode,
          tabIndex: 3,
          title: 'Satu akun, dua peran',
          body:
              'Kalau akunmu sudah terverifikasi sebagai Mitra, kamu bisa berpindah peran tanpa membuat akun baru.',
          assetPath: 'assets/images/ayos/ayos_run.png',
        ),
        _TutorialStep(
          target: widget.anchors.profileFinance,
          tabIndex: 3,
          title: 'Saldo & riwayat transaksi',
          body:
              'Area ini menjadi pintu untuk saldo AyoPay dan riwayat pembayaran Customer. Fitur uang tetap mengikuti flow pembayaran Ayo Suruh yang aktif.',
          assetPath: 'assets/images/ayos/ayos_thumbs_up.png',
          preferAbove: true,
        ),
      ];

  List<_TutorialStep> _mitraSteps() => <_TutorialStep>[
        _TutorialStep(
          target: widget.anchors.homeHeader,
          tabIndex: 0,
          title: 'Kenalan dengan area Mitra 👋',
          body:
              'AYOS akan tunjukin bagian yang paling sering kamu pakai untuk menerima pekerjaan dan mengelola jasa.',
          assetPath: 'assets/images/ayos/ayos_hello.png',
        ),
        _TutorialStep(
          target: widget.anchors.homeSearchOrIncome,
          tabIndex: 0,
          title: 'Pantau pendapatanmu',
          body:
              'Ringkasan pendapatan memberi gambaran hasil pekerjaan yang sudah tercatat. Detail saldo tersedia, pending, dan ditahan ada di Dompet Mitra.',
          assetPath: 'assets/images/ayos/ayos_thumbs_up.png',
        ),
        _TutorialStep(
          target: widget.anchors.homePromoOrService,
          tabIndex: 0,
          title: 'Jasa Saya = etalase Mitra',
          body:
              'Publikasikan keahlianmu di sini. Tambahkan cover dan foto katalog supaya Customer bisa melihat jasa yang kamu tawarkan.',
          assetPath: 'assets/images/ayos/ayos_idea.png',
        ),
        _TutorialStep(
          target: widget.anchors.homeCategoriesOrActive,
          tabIndex: 0,
          title: 'Pekerjaan Aktif',
          body:
              'Kalau penawaranmu diterima, pekerjaan aktif tampil di sini. Gunakan detail pekerjaan untuk memperbarui progres sampai selesai.',
          assetPath: 'assets/images/ayos/ayos_board_task.png',
        ),
        _TutorialStep(
          target: widget.anchors.navJobs,
          tabIndex: 0,
          title: 'Cari dan pantau pekerjaan',
          body:
              'Pekerjaan memisahkan daftar Tersedia, Pengajuan, dan Aktif supaya status penawaran dan pekerjaan tetap mudah dipantau.',
          assetPath: 'assets/images/ayos/ayos_pointing_left.png',
          preferAbove: true,
        ),
        _TutorialStep(
          target: widget.anchors.jobsOverview,
          tabIndex: 1,
          title: 'Jobs punya tiga antrean penting',
          body:
              'Tersedia untuk mencari job, Pengajuan untuk memantau bid, dan Aktif untuk pekerjaan yang sudah dipercayakan kepadamu.',
          assetPath: 'assets/images/ayos/ayos_run.png',
        ),
        _TutorialStep(
          target: widget.anchors.navChat,
          tabIndex: 1,
          title: 'Koordinasi ada di tab Chat',
          body:
              'Setelah pekerjaan terhubung dengan Customer, gunakan tab Chat untuk komunikasi yang tetap terkait dengan job.',
          assetPath: 'assets/images/ayos/ayos_play_phone.png',
          preferAbove: true,
        ),
        _TutorialStep(
          target: widget.anchors.chatOverview,
          tabIndex: 2,
          title: 'Koordinasikan pekerjaan lewat Chat',
          body:
              'Gunakan percakapan terkait job untuk memastikan kebutuhan, lokasi, dan progres tetap jelas dengan Customer.',
          assetPath: 'assets/images/ayos/ayos_play_phone.png',
        ),
        _TutorialStep(
          target: widget.anchors.navProfile,
          tabIndex: 2,
          title: 'Profile Mitra ada di sini',
          body:
              'Dari Profile kamu bisa berpindah peran, membuka dompet dan rekening, melihat riwayat, bantuan, serta pengaturan akun.',
          assetPath: 'assets/images/ayos/ayos_idea.png',
          preferAbove: true,
        ),
        _TutorialStep(
          target: widget.anchors.profileHeader,
          tabIndex: 3,
          title: 'Profile Mitra',
          body:
              'Profile menyatukan identitas, rating, riwayat pekerjaan, lokasi, rekening, bantuan, dan pengaturan akun.',
          assetPath: 'assets/images/ayos/ayos_idea.png',
        ),
        _TutorialStep(
          target: widget.anchors.profileMode,
          tabIndex: 3,
          title: 'Balik ke Customer kapan saja',
          body:
              'Menjadi Mitra tidak menghapus fungsi Customer. Gunakan pilihan peran ini untuk berpindah tanpa membuat akun baru.',
          assetPath: 'assets/images/ayos/ayos_run.png',
        ),
        _TutorialStep(
          target: widget.anchors.profileFinance,
          tabIndex: 3,
          title: 'Dompet & pencairan',
          body:
              'Pendapatan tersedia dapat dicairkan dari sini. Dompet juga menjelaskan saldo Pending, Available, Held, rekening, dan status pencairan.',
          assetPath: 'assets/images/ayos/ayos_hooray_with_confetti.png',
          preferAbove: true,
        ),
      ];

  Future<void> _prepareCurrentStep() async {
    if (!mounted || _steps.isEmpty) return;
    setState(() => _preparing = true);

    _TutorialStep step = _steps[_index];
    await widget.onSelectTab(step.tabIndex);
    await WidgetsBinding.instance.endOfFrame;

    // Dashboard/Profile memuat data secara async. Tunggu anchor UI asli
    // tersedia agar tutorial tidak meloncat hanya karena API belum selesai.
    BuildContext? targetContext;
    for (int attempt = 0; attempt < 30; attempt++) {
      if (!mounted) return;
      targetContext = step.target.currentContext;
      if (targetContext != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await WidgetsBinding.instance.endOfFrame;
    }

    // Beberapa target (mis. wallet di Profile) berada di bawah fold. Scroll
    // halaman aslinya terlebih dahulu sebelum menghitung spotlight.
    if (targetContext != null) {
      try {
        await Scrollable.ensureVisible(
          targetContext,
          alignment: 0.34,
          duration: const Duration(milliseconds: 330),
          curve: Curves.easeOutCubic,
        );
      } catch (_) {
        // Target yang bukan bagian dari Scrollable tetap dapat disorot.
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }

    if (!mounted) return;
    targetContext = step.target.currentContext;

    // Jika sebuah elemen memang tidak tersedia untuk akun ini (contoh switch
    // mode pada Customer yang belum jadi Mitra), lanjut otomatis ke step berikut.
    if (targetContext == null) {
      if (_index < _steps.length - 1) {
        _index++;
        await _prepareCurrentStep();
      } else {
        Navigator.of(context).pop();
      }
      return;
    }

    final RenderObject? object = targetContext.findRenderObject();
    if (object is! RenderBox || !object.hasSize) {
      if (_index < _steps.length - 1) {
        _index++;
        await _prepareCurrentStep();
      } else {
        Navigator.of(context).pop();
      }
      return;
    }

    final Offset topLeft = object.localToGlobal(Offset.zero);
    final Rect rect = topLeft & object.size;
    if (!mounted) return;
    setState(() {
      _targetRect = rect.inflate(6);
      _preparing = false;
    });
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
    final bool placeAbove = step.preferAbove ||
        (target != null && target.center.dy > screen.height * 0.55);

    double? top;
    double? bottom;
    if (target != null) {
      if (placeAbove) {
        bottom = (screen.height - target.top + 14)
            .clamp(
              88,
              screen.height - cardEstimatedHeight - 12,
            )
            .toDouble();
      } else {
        top = (target.bottom + 14)
            .clamp(
              18,
              screen.height - cardEstimatedHeight - 88,
            )
            .toDouble();
      }
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          CustomPaint(
            painter: _SpotlightPainter(targetRect: target),
          ),
          if (_preparing || target == null)
            const Center(
              child: CircularProgressIndicator(color: _orange),
            )
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
                      scale: Tween<double>(begin: 0.97, end: 1).animate(animation),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFDCA5)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 10),
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
                  color: const Color(0xFFFFE8C5),
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
                    Text(
                      widget.mode == 'mitra'
                          ? 'AYOS · Panduan Mitra'
                          : 'AYOS · Panduan Aplikasi',
                      style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.7,
                        fontWeight: FontWeight.w800,
                        color: _orange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.title,
                      style: AyoTypography.accent(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w600,
                        color: _brown,
                        height: 1.12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4EEE8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_index + 1}/${_steps.length}',
                  style: const TextStyle(
                    color: Color(0xFF74665D),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            step.body,
            style: const TextStyle(
              color: Color(0xFF625750),
              fontSize: 12,
              height: 1.48,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              TextButton(
                onPressed: _skip,
                child: const Text(
                  'Lewati',
                  style: TextStyle(color: Color(0xFF81766F)),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _next,
                style: FilledButton.styleFrom(
                  backgroundColor: _brown,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                ),
                icon: Icon(
                  last ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  size: 17,
                ),
                label: Text(last ? 'Mulai pakai Ayo Suruh' : 'Lanjut'),
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
      path.addRRect(
        RRect.fromRectAndRadius(target, const Radius.circular(18)),
      );
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
