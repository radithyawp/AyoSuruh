import 'package:flutter/material.dart';
import '../widgets/ayo_snackbar.dart';

import 'feedback_service.dart';

class AppFeedbackPage extends StatefulWidget {
  const AppFeedbackPage({super.key});

  @override
  State<AppFeedbackPage> createState() => _AppFeedbackPageState();
}

class _AppFeedbackPageState extends State<AppFeedbackPage> {
  static const Color _brown = Color(0xFF7B4B00);
  static const Color _orange = Color(0xFFF6990E);
  static const Color _green = Color(0xFFA4B792);
  static const Color _background = Color(0xFFFFFAFD);

  final FeedbackService _service = FeedbackService();
  final PageController _pageController = PageController();
  final TextEditingController _bugController = TextEditingController();
  final TextEditingController _likedController = TextEditingController();
  final TextEditingController _improvementController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  int _step = 0;
  String? _role;
  int? _easeRating;
  int? _discoverabilityRating;
  int? _uiRating;
  String? _performance;
  int? _trustRating;
  final Set<String> _features = <String>{};
  bool? _foundBug;
  int? _nps;
  bool _allowFollowup = false;
  bool _submitting = false;

  static const List<String> _featureOptions = <String>[
    'Pasang Pekerjaan',
    'Cari Pekerjaan',
    'Katalog Jasa',
    'Chat',
    'Notifikasi',
    'Pembayaran',
    'Dompet Mitra',
    'Lokasi',
  ];

  @override
  void initState() {
    super.initState();
    _role = _service.suggestedRole;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bugController.dispose();
    _likedController.dispose();
    _improvementController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool error = false}) {
    if (error) {
      AyoSnackBar.error(context, message);
    } else {
      AyoSnackBar.info(context, message);
    }
  }

  bool _validateCurrentStep() {
    if (_step == 0) {
      if (_role == null ||
          _easeRating == null ||
          _discoverabilityRating == null ||
          _uiRating == null ||
          _performance == null) {
        _showMessage('Lengkapi penilaian pengalamanmu dulu ya.');
        return false;
      }
    }
    if (_step == 1) {
      if (_trustRating == null || _features.isEmpty || _foundBug == null) {
        _showMessage('Lengkapi bagian fitur dan kepercayaan terlebih dahulu.');
        return false;
      }
      if (_foundBug == true && _bugController.text.trim().isEmpty) {
        _showMessage(
          'Ceritakan bug yang kamu temukan agar tim AYOS bisa mengeceknya.',
        );
        return false;
      }
    }
    if (_step == 2) {
      if (_likedController.text.trim().isEmpty ||
          _improvementController.text.trim().isEmpty ||
          _nps == null) {
        _showMessage(
          'Isi pendapat utama dan skor rekomendasi terlebih dahulu.',
        );
        return false;
      }
      if (_allowFollowup && _contactController.text.trim().isEmpty) {
        _showMessage('Isi email atau WhatsApp jika kamu bersedia dihubungi.');
        return false;
      }
    }
    return true;
  }

  Future<void> _next() async {
    if (!_validateCurrentStep()) return;
    if (_step < 2) {
      setState(() => _step += 1);
      await _pageController.animateToPage(
        _step,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _submit();
  }

  Future<void> _back() async {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _step -= 1);
    await _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _submit() async {
    if (_submitting || !_validateCurrentStep()) return;
    setState(() => _submitting = true);
    try {
      await _service.submit(
        role: _role!,
        easeRating: _easeRating!,
        discoverabilityRating: _discoverabilityRating!,
        uiRating: _uiRating!,
        performance: _performance!,
        trustRating: _trustRating!,
        usefulFeatures: _features.toList(growable: false),
        foundBug: _foundBug!,
        bugDetails: _bugController.text.trim(),
        liked: _likedController.text.trim(),
        improvement: _improvementController.text.trim(),
        nps: _nps!,
        allowFollowup: _allowFollowup,
        contact: _contactController.text.trim(),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Image.asset(
                'assets/images/ayos/ayos_hooray_with_confetti.png',
                height: 132,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 8),
              const Text(
                'Makasih sudah bantu AYOS!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _brown,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Masukanmu sudah tersimpan dan akan dipakai untuk memperbaiki Ayo Suruh.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: Color(0xFF695F59),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: FilledButton.styleFrom(backgroundColor: _orange),
                  child: const Text(
                    'Selesai',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        _showMessage('Masukan belum terkirim: $error', error: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: _submitting ? null : _back,
          icon: const Icon(Icons.arrow_back_rounded, color: _brown),
        ),
        title: const Text(
          'Kritik & Saran',
          style: TextStyle(
            color: _brown,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: (_step + 1) / 3,
                            minHeight: 7,
                            backgroundColor: const Color(0xFFFFE8CA),
                            color: _orange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${_step + 1}/3',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: _brown,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Image.asset(
                        'assets/images/ayos/ayos_announce.png',
                        width: 76,
                        height: 76,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Bantu AYOS bikin Ayo Suruh lebih baik 👋',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                                color: _brown,
                                height: 1.25,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Sekitar 2–3 menit. Jawabanmu tidak akan dipublikasikan ke pengguna lain.',
                              style: TextStyle(
                                fontSize: 10.8,
                                height: 1.35,
                                color: Color(0xFF6C625D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: <Widget>[
                  _experienceStep(),
                  _featuresStep(),
                  _opinionStep(),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF0E7E2))),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _step == 2
                              ? Icons.send_rounded
                              : Icons.arrow_forward_rounded,
                        ),
                  label: Text(
                    _step == 2 ? 'Kirim Masukan' : 'Lanjut',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _experienceStep() {
    return _scroll(<Widget>[
      _sectionTitle(
        'Pengalaman menggunakan Ayo Suruh',
        'Ceritakan bagaimana aplikasi terasa saat dipakai sehari-hari.',
      ),
      _question('Kamu menggunakan Ayo Suruh sebagai apa?'),
      _choiceWrap(
        <String, String>{
          'customer': 'Customer',
          'mitra': 'Mitra',
          'both': 'Keduanya',
        },
        selected: _role,
        onSelected: (String value) => setState(() => _role = value),
      ),
      _dividerGap(),
      _question('Seberapa mudah menggunakan Ayo Suruh?'),
      _ratingSelector(
        _easeRating,
        (int value) => setState(() => _easeRating = value),
      ),
      _ratingLabels('Sulit', 'Sangat mudah'),
      _dividerGap(),
      _question(
        'Seberapa mudah menemukan layanan atau pekerjaan yang kamu butuhkan?',
      ),
      _ratingSelector(
        _discoverabilityRating,
        (int value) => setState(() => _discoverabilityRating = value),
      ),
      _ratingLabels('Sulit ditemukan', 'Sangat mudah'),
      _dividerGap(),
      _question('Apakah tampilan Ayo Suruh mudah dipahami?'),
      _ratingSelector(
        _uiRating,
        (int value) => setState(() => _uiRating = value),
      ),
      _ratingLabels('Membingungkan', 'Sangat jelas'),
      _dividerGap(),
      _question('Bagaimana performa aplikasi di perangkatmu?'),
      _choiceWrap(
        <String, String>{
          'very_smooth': 'Sangat lancar',
          'smooth': 'Lancar',
          'fair': 'Cukup',
          'slow': 'Lambat',
          'very_slow': 'Sangat lambat',
        },
        selected: _performance,
        onSelected: (String value) => setState(() => _performance = value),
      ),
    ]);
  }

  Widget _featuresStep() {
    return _scroll(<Widget>[
      _sectionTitle(
        'Fitur & kepercayaan',
        'Bagian ini membantu kami menentukan apa yang perlu dipertahankan dan diperbaiki.',
      ),
      _question('Seberapa aman dan percaya kamu menggunakan Ayo Suruh?'),
      _ratingSelector(
        _trustRating,
        (int value) => setState(() => _trustRating = value),
      ),
      _ratingLabels('Belum percaya', 'Sangat percaya'),
      _dividerGap(),
      _question(
        'Fitur apa yang paling berguna?',
        hint: 'Boleh pilih lebih dari satu.',
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _featureOptions.map((String feature) {
          final bool selected = _features.contains(feature);
          return FilterChip(
            selected: selected,
            label: Text(feature),
            avatar: Icon(
              selected ? Icons.check_rounded : Icons.add_rounded,
              size: 16,
            ),
            selectedColor: const Color(0xFFFFE3B6),
            checkmarkColor: _brown,
            side: const BorderSide(color: Color(0xFFEADBCF)),
            labelStyle: TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: _brown,
            ),
            onSelected: (_) => setState(() {
              if (selected) {
                _features.remove(feature);
              } else {
                _features.add(feature);
              }
            }),
          );
        }).toList(),
      ),
      _dividerGap(),
      _question('Pernah menemukan bug atau error?'),
      _choiceWrap(
        <String, String>{'no': 'Tidak', 'yes': 'Ya'},
        selected: _foundBug == null ? null : (_foundBug! ? 'yes' : 'no'),
        onSelected: (String value) =>
            setState(() => _foundBug = value == 'yes'),
      ),
      if (_foundBug == true) ...<Widget>[
        const SizedBox(height: 12),
        _textArea(
          controller: _bugController,
          label: 'Ceritakan bug yang kamu temukan',
          hint: 'Contoh: saat menekan tombol X, halaman menjadi merah...',
          maxLength: 700,
        ),
      ],
    ]);
  }

  Widget _opinionStep() {
    return _scroll(<Widget>[
      _sectionTitle(
        'Pendapat terakhir',
        'Jawaban terbuka paling membantu tim memahami pengalamanmu secara nyata.',
      ),
      _textArea(
        controller: _likedController,
        label: 'Apa yang paling kamu sukai dari Ayo Suruh?',
        hint:
            'Ceritakan fitur, tampilan, atau pengalaman yang menurutmu paling membantu.',
        maxLength: 600,
      ),
      const SizedBox(height: 14),
      _textArea(
        controller: _improvementController,
        label: 'Apa yang paling perlu kami perbaiki?',
        hint:
            'Boleh tentang fitur, kecepatan, desain, keamanan, pembayaran, atau hal lain.',
        maxLength: 800,
      ),
      _dividerGap(),
      _question(
        'Seberapa besar kemungkinan kamu merekomendasikan Ayo Suruh ke teman?',
      ),
      const SizedBox(height: 4),
      LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          const double spacing = 6;
          final double itemWidth = (constraints.maxWidth - (spacing * 5)) / 6;
          return Wrap(
            spacing: spacing,
            runSpacing: 7,
            children: List<Widget>.generate(11, (int index) {
              final bool selected = _nps == index;
              return SizedBox(
                width: itemWidth,
                height: 40,
                child: InkWell(
                  borderRadius: BorderRadius.circular(11),
                  onTap: () => setState(() => _nps = index),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? _orange : Colors.white,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: selected ? _orange : const Color(0xFFE8DCD4),
                      ),
                    ),
                    child: Text(
                      '$index',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: selected ? Colors.white : _brown,
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
      _ratingLabels('Tidak mungkin', 'Sangat mungkin'),
      _dividerGap(),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: _allowFollowup,
        activeThumbColor: _orange,
        title: const Text(
          'Boleh kami menghubungimu untuk follow-up?',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: _brown,
          ),
        ),
        subtitle: const Text(
          'Opsional. Kontak hanya dipakai untuk membahas masukan yang kamu kirim.',
          style: TextStyle(fontSize: 10.5, height: 1.35),
        ),
        onChanged: (bool value) => setState(() => _allowFollowup = value),
      ),
      if (_allowFollowup) ...<Widget>[
        const SizedBox(height: 8),
        TextField(
          controller: _contactController,
          maxLength: 120,
          keyboardType: TextInputType.emailAddress,
          decoration: _inputDecoration(
            'Email / WhatsApp',
            'Contoh: nama@email.com atau 08xxxx',
          ),
        ),
      ],
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7F1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _green.withValues(alpha: 0.5)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.privacy_tip_outlined,
              color: Color(0xFF5F784F),
              size: 18,
            ),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Nama atau kontak tidak wajib. Jika follow-up dimatikan, form tidak menyimpan kontak tambahan.',
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.4,
                  color: Color(0xFF586552),
                ),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _scroll(List<Widget> children) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: _brown,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11.2,
              height: 1.4,
              color: Color(0xFF746A64),
            ),
          ),
        ],
      ),
    );
  }

  Widget _question(String text, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            text,
            style: const TextStyle(
              fontSize: 12.8,
              fontWeight: FontWeight.w800,
              color: _brown,
            ),
          ),
          if (hint != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              hint,
              style: const TextStyle(fontSize: 10.3, color: Color(0xFF847A74)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _choiceWrap(
    Map<String, String> choices, {
    required String? selected,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: choices.entries.map((MapEntry<String, String> entry) {
        final bool active = selected == entry.key;
        return ChoiceChip(
          selected: active,
          showCheckmark: true,
          checkmarkColor: _brown,
          selectedColor: const Color(0xFFFFE3B6),
          side: const BorderSide(color: Color(0xFFE8DCD4)),
          label: Text(entry.value),
          labelStyle: TextStyle(
            fontSize: 11.5,
            fontWeight: active ? FontWeight.w900 : FontWeight.w600,
            color: _brown,
          ),
          onSelected: (_) => onSelected(entry.key),
        );
      }).toList(),
    );
  }

  Widget _ratingSelector(int? selected, ValueChanged<int> onSelected) {
    return Row(
      children: List<Widget>.generate(5, (int index) {
        final int value = index + 1;
        final bool active = selected == value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 4 ? 0 : 7),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelected(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 43,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? _orange : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? _orange : const Color(0xFFE8DCD4),
                  ),
                ),
                child: Text(
                  '$value',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: active ? Colors.white : _brown,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _ratingLabels(String start, String end) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            start,
            style: const TextStyle(fontSize: 9.5, color: Color(0xFF8A807A)),
          ),
          Text(
            end,
            style: const TextStyle(fontSize: 9.5, color: Color(0xFF8A807A)),
          ),
        ],
      ),
    );
  }

  Widget _textArea({
    required TextEditingController controller,
    required String label,
    required String hint,
    required int maxLength,
  }) {
    return TextField(
      controller: controller,
      minLines: 3,
      maxLines: 6,
      maxLength: maxLength,
      textCapitalization: TextCapitalization.sentences,
      decoration: _inputDecoration(label, hint),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: true,
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: _brown, fontWeight: FontWeight.w700),
      hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFA59B95)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFE8DCD4)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFE8DCD4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _orange, width: 1.5),
      ),
    );
  }

  Widget _dividerGap() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Divider(height: 1, color: Color(0xFFF0E7E2)),
    );
  }
}
