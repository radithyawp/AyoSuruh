import 'package:flutter/material.dart';
import '../jobs/job_helpers.dart';
import '../widgets/ayo_empty_state.dart';
import '../widgets/home_shortcut_button.dart';
import 'voucher_service.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';
import '../theme/ayo_theme.dart';

Color get _voucherBrown => AyoAdaptiveColors.brown;
const Color _voucherOrange = Color(0xFFF6990E);
const Color _voucherGreen = Color(0xFF5E774F);

class VoucherPage extends StatefulWidget {
  const VoucherPage({super.key});

  @override
  State<VoucherPage> createState() => _VoucherPageState();
}

class _VoucherPageState extends State<VoucherPage> {
  final VoucherService _service = VoucherService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _vouchers = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final List<Map<String, dynamic>> vouchers =
          await _service.fetchMyVouchers();
      if (!mounted) return;
      setState(() {
        _vouchers = vouchers;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: _voucherBrown),
        ),
        title: AyoText(
          'Voucher Saya',
          style: TextStyle(
            color: _voucherBrown,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: const <Widget>[HomeShortcutButton()],
      ),
      body: RefreshIndicator(
        color: _voucherOrange,
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const <Widget>[
          SizedBox(height: 240),
          Center(child: CircularProgressIndicator(color: _voucherOrange)),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          const SizedBox(height: 110),
          Icon(Icons.local_activity_outlined, size: 58, color: _voucherBrown),
          const SizedBox(height: 12),
          const AyoText(
            'Voucher belum dapat dimuat',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          AyoText(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton(onPressed: _load, child: const AyoText('Coba Lagi')),
        ],
      );
    }

    final List<Map<String, dynamic>> available = _vouchers
        .where((Map<String, dynamic> row) => row['status'] == 'available')
        .toList();
    final List<Map<String, dynamic>> history = _vouchers
        .where((Map<String, dynamic> row) => row['status'] != 'available')
        .toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 34),
      children: <Widget>[
        _introCard(available.length),
        const SizedBox(height: 22),
        if (available.isNotEmpty) ...<Widget>[
          const _SectionTitle('Siap Digunakan'),
          const SizedBox(height: 10),
          ...available.map(_voucherCard),
        ] else
          _emptyCard(),
        if (history.isNotEmpty) ...<Widget>[
          const SizedBox(height: 22),
          const _SectionTitle('Riwayat Voucher'),
          const SizedBox(height: 10),
          ...history.map(_voucherCard),
        ],
      ],
    );
  }

  Widget _introCard(int availableCount) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8C6),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.confirmation_number_rounded, color: _voucherBrown),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AyoText(
                  '$availableCount voucher tersedia',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                const AyoText(
                  'Voucher diberikan otomatis sesuai syarat akun. Pilih voucher saat checkout setelah metode pembayaran tersedia.',
                  style: TextStyle(fontSize: 11.5, height: 1.4, color: Color(0xFF6D5C50)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.all(Radius.circular(20)),
        border: Border.fromBorderSide(
          BorderSide(color: Color(0xFFEAD8CB)),
        ),
      ),
      child: AyoEmptyState(
        compact: true,
        assetPath: 'assets/images/ayos/ayos_empty.png',
        badgeIcon: Icons.local_activity_outlined,
        title: 'Belum ada voucher aktif',
        description:
            'Promo akan masuk otomatis saat akunmu memenuhi syarat campaign Ayo Suruh.',
      ),
    );
  }

  Widget _voucherCard(Map<String, dynamic> voucher) {
    final String status = (voucher['status'] ?? '').toString();
    final bool available = status == 'available';
    final String asset = _assetFor(voucher['art_asset_key']?.toString());

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showTerms(voucher),
          child: Opacity(
            opacity: available ? 1 : 0.58,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFEAD8CB)),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AspectRatio(
                    aspectRatio: 2,
                    child: Image.asset(asset, fit: BoxFit.cover),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: AyoText(
                                _discountLabel(voucher),
                                style: TextStyle(
                                  color: _voucherBrown,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            _statusChip(status),
                          ],
                        ),
                        const SizedBox(height: 5),
                        AyoText(
                          'Min. transaksi ${formatRupiah(_asNum(voucher['min_transaction']))}',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        AyoText(
                          _validityLabel(voucher),
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF7C716B)),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: <Widget>[
                            AyoText(
                              (voucher['code'] ?? '').toString(),
                              style: const TextStyle(
                                color: _voucherOrange,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const Spacer(),
                            AyoText(
                              'Lihat S&K',
                              style: TextStyle(
                                decoration: TextDecoration.underline,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: _voucherBrown,
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
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    String label;
    Color foreground;
    Color background;
    switch (status) {
      case 'used':
        label = 'Terpakai';
        foreground = const Color(0xFF73655D);
        background = const Color(0xFFEDE7E3);
        break;
      case 'expired':
        label = 'Kedaluwarsa';
        foreground = const Color(0xFF8A5A18);
        background = const Color(0xFFFFE7C0);
        break;
      case 'cancelled':
        label = 'Tidak Berlaku';
        foreground = Colors.red.shade700;
        background = const Color(0xFFFFE1DE);
        break;
      case 'reserved':
        label = 'Dipakai di Checkout';
        foreground = const Color(0xFF6E481F);
        background = const Color(0xFFFFE7C0);
        break;
      default:
        label = 'Tersedia';
        foreground = _voucherGreen;
        background = const Color(0xFFE5F2DD);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: AyoText(
        label,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: foreground),
      ),
    );
  }

  Future<void> _showTerms(Map<String, dynamic> voucher) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8CEC8),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 17),
                AyoText(
                  (voucher['title'] ?? 'Voucher Ayo Suruh').toString(),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                AyoText(
                  (voucher['subtitle'] ?? '').toString(),
                  style: const TextStyle(color: Color(0xFF746A64)),
                ),
                const SizedBox(height: 16),
                _termRow(Icons.sell_outlined, 'Benefit', _discountLabel(voucher)),
                _termRow(
                  Icons.payments_outlined,
                  'Minimum transaksi',
                  formatRupiah(_asNum(voucher['min_transaction'])),
                ),
                _termRow(Icons.schedule_rounded, 'Masa berlaku', _validityLabel(voucher)),
                _termRow(
                  Icons.repeat_rounded,
                  'Pemakaian',
                  '1 kali per akun dan tidak dapat digabung dengan voucher lain',
                ),
                if ((voucher['eligibility_type'] ?? '').toString() == 'first_transaction')
                  _termRow(
                    Icons.auto_awesome_outlined,
                    'Syarat khusus',
                    'Hanya untuk transaksi pekerjaan pertama sebagai Customer.',
                  ),
                if ((voucher['eligibility_type'] ?? '').toString() == 'ayopay_activation')
                  _termRow(
                    Icons.account_balance_wallet_outlined,
                    'Syarat khusus',
                    'AyoPay harus tetap aktif saat voucher digunakan.',
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: _voucherBrown,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const AyoText('Mengerti', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _termRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: _voucherOrange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AyoText(title, style: const TextStyle(fontSize: 10.5, color: Color(0xFF867B75))),
                const SizedBox(height: 1),
                AyoText(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _assetFor(String? key) {
    switch (key) {
      case 'ayopay_welcome':
        return 'assets/images/vouchers/ayopay_welcome.png';
      case 'first_try':
      default:
        return 'assets/images/vouchers/first_try.png';
    }
  }

  String _discountLabel(Map<String, dynamic> voucher) {
    final num value = _asNum(voucher['discount_value']);
    final String type = (voucher['discount_type'] ?? 'fixed').toString();
    if (type == 'percent') {
      final num maxDiscount = _asNum(voucher['max_discount']);
      return maxDiscount > 0
          ? '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}% OFF • maks. ${formatRupiah(maxDiscount)}'
          : '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}% OFF';
    }
    return '${formatRupiah(value)} OFF';
  }

  String _validityLabel(Map<String, dynamic> voucher) {
    final DateTime? expiry =
        DateTime.tryParse((voucher['expires_at'] ?? '').toString())?.toLocal();
    if (expiry == null) return 'Masa berlaku mengikuti periode promo';
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return 'Berlaku sampai ${expiry.day} ${months[expiry.month - 1]} ${expiry.year}';
  }

  num _asNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return AyoText(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF302A27)),
    );
  }
}
