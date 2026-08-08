import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AyosTutorial {
  AyosTutorial._();

  static const String _version = 'v1';

  static String _normalizedMode(String mode) =>
      mode.trim().toLowerCase() == 'mitra' ? 'mitra' : 'customer';

  static String _seenKey(String mode) =>
      'ayos_tutorial_${_normalizedMode(mode)}_$_version';

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
  }) async {
    if (await hasSeen(mode) || !context.mounted) return;
    await show(context, mode: mode);
  }

  static Future<void> show(
    BuildContext context, {
    required String mode,
  }) async {
    if (!context.mounted) return;
    final String normalized = _normalizedMode(mode);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AyosTutorialDialog(mode: normalized),
    );
    await markSeen(normalized);
  }
}

class _TutorialStep {
  const _TutorialStep({
    required this.title,
    required this.body,
    required this.icon,
    required this.assetPath,
  });

  final String title;
  final String body;
  final IconData icon;
  final String assetPath;
}

class _AyosTutorialDialog extends StatefulWidget {
  const _AyosTutorialDialog({required this.mode});

  final String mode;

  @override
  State<_AyosTutorialDialog> createState() => _AyosTutorialDialogState();
}

class _AyosTutorialDialogState extends State<_AyosTutorialDialog> {
  static const Color _orange = Color(0xFFF39C12);
  static const Color _brown = Color(0xFF8B5A2B);
  static const Color _background = Color(0xFFFFFBF7);

  final PageController _controller = PageController();
  int _page = 0;

  List<_TutorialStep> get _steps => widget.mode == 'mitra'
      ? const <_TutorialStep>[
          _TutorialStep(
            title: 'Halo Mitra, aku AYOS!',
            body:
                'Aku akan bantu kamu mengenali alur kerja Mitra Ayo Suruh. Kamu tetap bisa memakai Mode Customer dari akun yang sama.',
            icon: Icons.handyman_rounded,
            assetPath: 'assets/images/ayos/ayos_hello.png',
          ),
          _TutorialStep(
            title: 'Temukan kebutuhan customer',
            body:
                'Buka Home atau Jobs untuk melihat pekerjaan yang tersedia. Pilih pekerjaan yang sesuai dengan kemampuan dan lokasi kamu.',
            icon: Icons.travel_explore_rounded,
            assetPath: 'assets/images/ayos/ayos_run.png',
          ),
          _TutorialStep(
            title: 'Kirim penawaran yang transparan',
            body:
                'Ajukan harga dan estimasi pengerjaan. Sebelum mengirim bid, Ayo Suruh menampilkan estimasi pendapatan bersih setelah komisi platform 6%.',
            icon: Icons.request_quote_rounded,
            assetPath: 'assets/images/ayos/ayos_board_task.png',
          ),
          _TutorialStep(
            title: 'Kerjakan, chat, lalu cairkan',
            body:
                'Setelah bid diterima, gunakan chat dan update progres sampai selesai. Pendapatan bersih masuk ke Dompet Mitra dan dapat diajukan untuk pencairan.',
            icon: Icons.account_balance_wallet_rounded,
            assetPath: 'assets/images/ayos/ayos_thumbs_up.png',
          ),
        ]
      : const <_TutorialStep>[
          _TutorialStep(
            title: 'Halo, aku AYOS!',
            body:
                'Aku akan jadi pemandu singkat kamu di Ayo Suruh. Cari bantuan, buat pekerjaan, dan pantau semuanya dari satu aplikasi.',
            icon: Icons.waving_hand_rounded,
            assetPath: 'assets/images/ayos/ayos_hello.png',
          ),
          _TutorialStep(
            title: 'Cari layanan yang kamu butuhkan',
            body:
                'Gunakan kolom Cari Layanan atau pilih katalog seperti Elektronik, Antar-Jemput, Jasa Titip, Design & Coding, dan lainnya.',
            icon: Icons.search_rounded,
            assetPath: 'assets/images/ayos/ayos_play_phone.png',
          ),
          _TutorialStep(
            title: 'Buat pekerjaan dan pilih mitra',
            body:
                'Isi detail, lokasi, jadwal, dan estimasi harga. Mitra dapat memberikan penawaran, lalu kamu memilih penawaran yang paling sesuai.',
            icon: Icons.work_outline_rounded,
            assetPath: 'assets/images/ayos/ayos_board_task.png',
          ),
          _TutorialStep(
            title: 'Pantau sampai selesai',
            body:
                'Gunakan chat untuk koordinasi, lakukan pembayaran melalui alur Ayo Suruh, pantau progres, lalu beri rating setelah pekerjaan selesai.',
            icon: Icons.task_alt_rounded,
            assetPath: 'assets/images/ayos/ayos_hooray_with_confetti.png',
          ),
        ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page >= _steps.length - 1) {
      Navigator.pop(context);
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool last = _page == _steps.length - 1;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                height: 174,
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0xFFFFE0A4), Color(0xFFFFF1D8)],
                  ),
                ),
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      right: -12,
                      bottom: -2,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        child: Image.asset(
                          _steps[_page].assetPath,
                          key: ValueKey<String>(_steps[_page].assetPath),
                          height: 160,
                        fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.smart_toy_rounded,
                            size: 118,
                            color: _orange,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.86),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          widget.mode == 'mitra'
                              ? 'Tutorial Mode Mitra'
                              : 'Tutorial Mode Customer',
                          style: const TextStyle(
                            color: _brown,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 252,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _steps.length,
                  onPageChanged: (int value) => setState(() => _page = value),
                  itemBuilder: (BuildContext context, int index) {
                    final _TutorialStep step = _steps[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE8C0),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(step.icon, color: _brown, size: 24),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            step.title,
                            style: const TextStyle(
                              color: Color(0xFF302722),
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            step.body,
                            style: const TextStyle(
                              color: Color(0xFF6F635C),
                              fontSize: 12.2,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List<Widget>.generate(
                        _steps.length,
                        (int index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: index == _page ? 24 : 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: index == _page
                                ? _orange
                                : const Color(0xFFE2D6CF),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Lewati',
                            style: TextStyle(
                              color: Color(0xFF76665D),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _next,
                          style: FilledButton.styleFrom(
                            backgroundColor: _orange,
                            foregroundColor: const Color(0xFF4C3100),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 13,
                            ),
                          ),
                          icon: Icon(
                            last
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                          label: Text(
                            last ? 'Mulai' : 'Lanjut',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
