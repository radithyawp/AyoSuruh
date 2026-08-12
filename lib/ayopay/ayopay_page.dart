import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../jobs/job_helpers.dart';
import '../widgets/ayo_snackbar.dart';
import '../widgets/ayo_empty_state.dart';
import '../widgets/home_shortcut_button.dart';
import '../wallet/wallet_pin_page.dart';
import '../wallet/wallet_service.dart';
import '../vouchers/voucher_page.dart';
import 'ayopay_service.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';
import '../theme/ayo_theme.dart';

const Color _ayoPayOrange = Color(0xFFF6990E);
Color get _ayoPayBrown => AyoAdaptiveColors.brown;
const Color _ayoPayGreen = Color(0xFF5E774F);

class AyoPayPage extends StatefulWidget {
  const AyoPayPage({super.key});

  @override
  State<AyoPayPage> createState() => _AyoPayPageState();
}

class _AyoPayPageState extends State<AyoPayPage> {
  final AyoPayService _service = AyoPayService();
  final WalletService _walletService = WalletService();

  bool _loading = true;
  bool _activating = false;
  String? _error;
  Map<String, dynamic> _summary = <String, dynamic>{};
  List<Map<String, dynamic>> _ledger = <Map<String, dynamic>>[];

  bool get _active => _summary['is_active'] == true;
  num get _balance => _asNum(_summary['balance']);

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
      final Map<String, dynamic> summary = await _service.fetchSummary();
      final List<Map<String, dynamic>> ledger =
          summary['is_active'] == true
              ? await _service.fetchLedger()
              : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _ledger = ledger;
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

  Future<void> _activate() async {
    if (_activating) return;

    final bool pinReady = await ensureWalletPinConfigured(
      context,
      _walletService,
    );
    if (!pinReady || !mounted) return;

    setState(() => _activating = true);
    try {
      await _service.activate();
      if (!mounted) return;
      AyoSnackBar.success(
        context,
        'AyoPay berhasil diaktifkan. Voucher aktivasi akan otomatis masuk ke Voucher Saya.',
      );
      await _load();
    } on AyoPayException catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(context, error.message);
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(context, 'AyoPay belum dapat diaktifkan: $error');
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }

  Future<void> _openPin() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => const WalletPinPage()),
    );
    if (mounted) await _load();
  }

  Future<void> _openVouchers() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const VoucherPage()),
    );
    if (mounted) await _load();
  }

  void _showTopUpInfo() {
    AyoSnackBar.info(
      context,
      'Top up AyoPay akan diaktifkan setelah metode pembayaran online siap. Untuk sementara saldo dapat berasal dari promo/voucher yang valid.',
    );
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
          icon: Icon(Icons.arrow_back_rounded, color: _ayoPayBrown),
        ),
        title: AyoText(
          'AyoPay',
          style: TextStyle(
            color: _ayoPayBrown,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: const <Widget>[HomeShortcutButton()],
      ),
      body: RefreshIndicator(
        color: _ayoPayOrange,
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
          Center(child: CircularProgressIndicator(color: _ayoPayOrange)),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          const SizedBox(height: 90),
          Icon(Icons.error_outline_rounded, size: 54, color: _ayoPayBrown),
          const SizedBox(height: 12),
          AyoText(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const AyoText('Coba Lagi')),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 34),
      children: <Widget>[
        if (_active) ...<Widget>[
          _balanceCard(),
          const SizedBox(height: 14),
          _quickActions(),
          const SizedBox(height: 18),
          _statusInfoCard(),
          const SizedBox(height: 22),
          _ledgerSection(),
        ] else ...<Widget>[
          _activationHero(),
          const SizedBox(height: 16),
          _voucherActivationTeaser(),
          const SizedBox(height: 16),
          _whyAyoPayCard(),
        ],
      ],
    );
  }

  Widget _activationHero() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFFFE2B2), Color(0xFFFFF5E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFC96D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              color: _ayoPayBrown,
              size: 29,
            ),
          ),
          const SizedBox(height: 16),
          AyoText(
            'Aktifkan AyoPay',
            style: TextStyle(
              color: _ayoPayBrown,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          const AyoText(
            'Satu dompet untuk saldo promo, voucher, dan metode pembayaran Ayo Suruh yang akan tersedia bertahap.',
            style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF6D5C50)),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: _activating ? null : _activate,
              style: FilledButton.styleFrom(
                backgroundColor: _ayoPayBrown,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: _activating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.lock_open_rounded),
              label: const AyoText(
                'Aktifkan Sekarang',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _voucherActivationTeaser() {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openVouchers,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFEAD8CB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const AspectRatio(
                aspectRatio: 2,
                child: Image(
                  image: AssetImage('assets/images/vouchers/ayopay_welcome.png'),
                  fit: BoxFit.cover,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: AyoText(
                        'Aktifkan AyoPay untuk membuka voucher spesial. Benefit masuk otomatis ke akun setelah aktivasi.',
                        style: TextStyle(fontSize: 11.5, height: 1.4, color: Color(0xFF6D5C50)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, color: _ayoPayBrown.withValues(alpha: 0.75)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _whyAyoPayCard() {
    return _card(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AyoText(
            'Kenapa aktifkan AyoPay?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 13),
          _BenefitRow(
            icon: Icons.confirmation_number_outlined,
            text: 'Siap menerima promo dan voucher Ayo Suruh.',
          ),
          SizedBox(height: 11),
          _BenefitRow(
            icon: Icons.lock_outline_rounded,
            text: 'Dilindungi PIN AyoPay 6 digit untuk aksi finansial sensitif.',
          ),
          SizedBox(height: 11),
          _BenefitRow(
            icon: Icons.receipt_long_outlined,
            text: 'Riwayat perubahan saldo tercatat dalam ledger AyoPay.',
          ),
        ],
      ),
    );
  }

  Widget _balanceCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _ayoPayBrown,
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _ayoPayBrown.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFFFD38B)),
              SizedBox(width: 8),
              AyoText(
                'Saldo AyoPay',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AyoText(
            formatRupiah(_balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 31,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          if (_summary['activated_at'] != null) ...<Widget>[
            const SizedBox(height: 10),
            AyoText(
              'Aktif sejak ${_formatDate(_summary['activated_at'])}',
              style: const TextStyle(color: Colors.white60, fontSize: 10.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _quickActions() {
    return Row(
      children: <Widget>[
        Expanded(
          child: _actionButton(
            icon: Icons.add_card_rounded,
            label: AyoI18n.t('Isi Saldo'),
            onTap: _showTopUpInfo,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actionButton(
            icon: Icons.confirmation_number_outlined,
            label: AyoI18n.t('Voucher'),
            onTap: _openVouchers,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actionButton(
            icon: Icons.lock_outline_rounded,
            label: AyoI18n.t('PIN AyoPay'),
            onTap: _openPin,
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 74,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEAD8CB)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: _ayoPayBrown, size: 24),
              const SizedBox(height: 5),
              AyoText(
                label,
                style: TextStyle(
                  color: _ayoPayBrown,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusInfoCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6EC),
        borderRadius: BorderRadius.circular(17),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.verified_user_outlined, color: _ayoPayGreen),
          SizedBox(width: 10),
          Expanded(
            child: AyoText(
              'AyoPay aktif. Saldo dan setiap mutasinya dicatat di server. Top up online belum dibuka sampai metode pembayaran siap.',
              style: TextStyle(
                color: Color(0xFF526347),
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ledgerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const AyoText(
          'Riwayat AyoPay',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 11),
        if (_ledger.isEmpty)
          _card(
            child: const AyoEmptyState(
              compact: true,
              assetPath: 'assets/images/ayos/ayos_empty.png',
              badgeIcon: Icons.receipt_long_outlined,
              title: 'Belum ada transaksi AyoPay',
              description: 'Mutasi saldo AyoPay akan tampil di sini setelah ada aktivitas.',
            ),
          )
        else
          ..._ledger.map(_ledgerTile),
      ],
    );
  }

  Widget _ledgerTile(Map<String, dynamic> row) {
    final num amount = _asNum(row['amount']);
    final bool positive = amount > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFEAD8CB)),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 20,
            backgroundColor: positive
                ? const Color(0xFFE2F1D8)
                : const Color(0xFFFFE4DF),
            child: Icon(
              positive ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: positive ? _ayoPayGreen : Colors.red.shade700,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AyoText(
                  (row['description'] ?? _entryLabel(row['entry_type'])).toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                AyoText(
                  _formatDate(row['created_at']),
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF8A7B72)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AyoText(
            '${positive ? '+' : '-'}${formatRupiah(amount.abs())}',
            style: TextStyle(
              color: positive ? _ayoPayGreen : Colors.red.shade700,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEAD8CB)),
      ),
      child: child,
    );
  }

  String _entryLabel(Object? raw) {
    switch ((raw ?? '').toString()) {
      case 'voucher_credit':
        return 'Voucher AyoPay';
      case 'activation_bonus':
        return 'Bonus aktivasi AyoPay';
      case 'topup':
        return 'Top up AyoPay';
      case 'job_payment':
        return 'Pembayaran pekerjaan';
      case 'refund':
        return 'Refund AyoPay';
      case 'admin_adjustment':
        return 'Penyesuaian saldo';
      default:
        return 'Transaksi AyoPay';
    }
  }

  String _formatDate(Object? raw) {
    final DateTime? value = DateTime.tryParse(raw?.toString() ?? '');
    if (value == null) return '-';
    return DateFormat('dd MMM yyyy, HH:mm').format(value.toLocal());
  }

  num _asNum(Object? value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0D7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _ayoPayBrown, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: AyoText(
              text,
              style: const TextStyle(fontSize: 12.5, height: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}
