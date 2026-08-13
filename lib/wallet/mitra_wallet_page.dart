import 'package:flutter/material.dart';
import '../widgets/ayo_snackbar.dart';
import 'package:intl/intl.dart';

import '../jobs/job_helpers.dart';
import 'mitra_bank_accounts_page.dart';
import 'wallet_service.dart';
import 'wallet_pin_page.dart';
import '../widgets/home_shortcut_button.dart';
import '../widgets/ayo_empty_state.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';
import '../theme/ayo_theme.dart';

Color get _walletBrown => AyoAdaptiveColors.brown;
const Color _walletOrange = Color(0xFFF6990E);
const Color _walletBackground = Color(0xFFFFF9FC);
const Color _walletGreen = Color(0xFF5E774F);

class MitraWalletPage extends StatefulWidget {
  const MitraWalletPage({super.key});

  @override
  State<MitraWalletPage> createState() => _MitraWalletPageState();
}

class _MitraWalletPageState extends State<MitraWalletPage> {
  final WalletService _service = WalletService();

  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _errorMessage;
  Map<String, dynamic> _summary = <String, dynamic>{};
  List<Map<String, dynamic>> _ledger = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _payouts = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _bankAccounts = <Map<String, dynamic>>[];
  Map<String, dynamic> _pinStatus = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
        _service.fetchSummary(),
        _service.fetchLedger(),
        _service.fetchPayouts(),
        _service.fetchBankAccounts(),
        _service.fetchPinStatus(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = result[0] as Map<String, dynamic>;
        _ledger = result[1] as List<Map<String, dynamic>>;
        _payouts = result[2] as List<Map<String, dynamic>>;
        _bankAccounts = result[3] as List<Map<String, dynamic>>;
        _pinStatus = result[4] as Map<String, dynamic>;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  num _number(Object? value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _openPayoutForm() async {
    final num available = _number(_summary['available_balance']);
    final num minimum = _number(_summary['minimum_payout']);

    if (available < minimum) {
      AyoSnackBar.info(
        context,
        'Saldo tersedia belum mencapai minimum ${formatRupiah(minimum)}.',
      );
      return;
    }
    if (_summary['active_payout_id'] != null) {
      AyoSnackBar.info(
        context,
        'Masih ada pencairan yang sedang diproses.',
      );
      return;
    }

    if (!await ensureWalletPinConfigured(context, _service)) return;
    if (!mounted) return;

    if (_bankAccounts.isEmpty) {
      await _openBankAccounts();
      if (!mounted) return;
      if (_bankAccounts.isEmpty) {
        AyoSnackBar.info(
          context,
          'Tambahkan rekening pencairan terlebih dahulu.',
        );
        return;
      }
    }

    final Map<String, dynamic>? bank = await _selectBankAccount();
    if (bank == null || !mounted) return;

    final bool? requested = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _PayoutFormSheet(
        availableBalance: available,
        minimumPayout: minimum,
        bankAccount: bank,
        onSubmit: (num amount, String pin) async {
          await _service.requestPayout(
            amount: amount,
            bankAccountId: bank['id'].toString(),
            pin: pin,
          );
        },
      ),
    );
    if (requested == true) await _load();
  }

  Future<void> _openBankAccounts() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const MitraBankAccountsPage()),
    );
    if (!mounted) return;
    await _load();
  }

  Future<Map<String, dynamic>?> _selectBankAccount() async {
    if (_bankAccounts.isEmpty) return null;
    if (_bankAccounts.length == 1) return _bankAccounts.first;

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
            children: <Widget>[
              AyoText(
                'Pilih Rekening Pencairan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _walletBrown,
                ),
              ),
              const SizedBox(height: 10),
              ..._bankAccounts.map((Map<String, dynamic> account) {
                final bool isDefault = account['is_default'] == true;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Color(0xFFFFE9C7),
                    child: Icon(
                      Icons.account_balance_rounded,
                      color: _walletBrown,
                    ),
                  ),
                  title: AyoText(
                    (account['bank_name'] ?? 'Rekening').toString(),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: AyoText(
                    '${_maskAccount(account['account_number'])} · ${(account['account_holder'] ?? '').toString()}',
                  ),
                  trailing: isDefault
                      ? const Icon(Icons.star_rounded, color: _walletOrange)
                      : null,
                  onTap: () => Navigator.pop(sheetContext, account),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  String _maskAccount(Object? raw) {
    final String value = (raw ?? '').toString().trim();
    if (value.length <= 4) return value;
    return '•••• ${value.substring(value.length - 4)}';
  }

  Future<void> _cancelPayout(Map<String, dynamic> payout) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const AyoText('Batalkan pencairan?'),
        content: const AyoText(
          'Saldo yang sedang ditahan akan dikembalikan ke saldo tersedia.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AyoText('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AyoText('Batalkan Pencairan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (!await ensureWalletPinConfigured(context, _service)) return;
    if (!mounted) return;
    final String? pin = await showWalletPinPrompt(
      context,
      title: 'Konfirmasi Pembatalan',
      message: 'Masukkan PIN AyoPay untuk membatalkan pencairan dan mengembalikan saldo ditahan.',
    );
    if (pin == null || !mounted) return;

    setState(() => _isActionLoading = true);
    try {
      await _service.cancelPayout(payout['id'].toString(), pin: pin);
      await _load();
      if (!mounted) return;
      AyoSnackBar.success(context, 'Pencairan berhasil dibatalkan.');
    } on WalletPinException catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(context, error.message);
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(
        context,
        'Pencairan belum dapat dibatalkan: $error',
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
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
          onPressed: () => Navigator.pop(context, true),
          icon: Icon(Icons.arrow_back_rounded, color: _walletBrown),
        ),
        title: AyoText(
          'Dompet Mitra',
          style: TextStyle(
            color: _walletBrown,
            fontWeight: FontWeight.w800,
            fontSize: 19,
          ),
        ),

        actions: const <Widget>[HomeShortcutButton()],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _walletOrange),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 54,
                color: _walletBrown,
              ),
              const SizedBox(height: 12),
              AyoText(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton(onPressed: _load, child: const AyoText('Coba Lagi')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: _walletOrange,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: <Widget>[
          _balanceCard(),
          if (_number(_summary['available_balance']) < 0) ...<Widget>[
            const SizedBox(height: 14),
            _walletObligationCard(),
          ],
          const SizedBox(height: 14),
          _walletSecurityCard(),
          const SizedBox(height: 14),
          _heldFundsInfoCard(),
          const SizedBox(height: 14),
          _bankCard(),
          if (_payouts.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            _payoutHistoryCard(),
          ],
          const SizedBox(height: 14),
          _ledgerCard(),
          const SizedBox(height: 14),
          _mockInfoCard(),
        ],
      ),
    );
  }

  Widget _balanceCard() {
    final num available = _number(_summary['available_balance']);
    final num minimum = _number(_summary['minimum_payout']);
    final num platformFee = _number(_summary['platform_fee_percent']);
    final String platformFeeLabel =
        platformFee.toDouble() == platformFee.roundToDouble()
        ? platformFee.toStringAsFixed(0)
        : platformFee.toStringAsFixed(2);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF6E481F), Color(0xFFB87516)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AyoText(
            'SALDO TERSEDIA',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          AyoText(
            formatRupiah(available),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          AyoText(
            'Pendapatan bersih setelah komisi platform $platformFeeLabel%.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _miniBalance(
                  'Pending',
                  _number(_summary['pending_balance']),
                  Icons.schedule_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniBalance(
                  'Ditahan',
                  _number(_summary['held_balance']),
                  Icons.lock_clock_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _isActionLoading ? null : _openPayoutForm,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _walletBrown,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              icon: const Icon(Icons.account_balance_rounded),
              label: AyoText(
                'Cairkan Saldo · Min. ${formatRupiah(minimum)}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _walletObligationCard() {
    final num available = _number(_summary['available_balance']);
    final num obligation = available < 0 ? available.abs() : 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE1DE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFB8AE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.receipt_long_rounded, color: Colors.red.shade700),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const AyoText(
                  'SALDO TERUTANG',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                AyoText(
                  formatRupiah(obligation),
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                const AyoText(
                  'Komisi Cash atau penyesuaian yang belum tertutup akan otomatis dipotong dari saldo dan pendapatan AyoPay berikutnya. Customer tidak dikenakan biaya tambahan.',
                  style: TextStyle(fontSize: 10.5, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniBalance(String label, num amount, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: Theme.of(context).colorScheme.surface, size: 18),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AyoText(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
                AyoText(
                  formatRupiah(amount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _walletSecurityCard() {
    final bool hasPin = _pinStatus['has_pin'] == true;
    final DateTime? lockedUntil = DateTime.tryParse(
      (_pinStatus['locked_until'] ?? '').toString(),
    )?.toLocal();
    final bool locked =
        lockedUntil != null && lockedUntil.isAfter(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: hasPin ? const Color(0xFFEAF4E3) : const Color(0xFFFFF0D9),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: hasPin ? const Color(0xFFC9DDBA) : const Color(0xFFF2D5A8),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              locked
                  ? Icons.lock_clock_rounded
                  : hasPin
                      ? Icons.verified_user_rounded
                      : Icons.shield_outlined,
              color: _walletBrown,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AyoText(
                  locked
                      ? 'PIN AyoPay dikunci sementara'
                      : hasPin
                          ? 'PIN AyoPay aktif'
                          : 'Aktifkan PIN AyoPay',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _walletBrown,
                  ),
                ),
                const SizedBox(height: 3),
                AyoText(
                  locked
                      ? 'Tunggu masa kunci berakhir atau reset PIN setelah verifikasi akun.'
                      : 'Melindungi pencairan dan perubahan rekening.',
                  style: const TextStyle(fontSize: 10.5, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _isActionLoading
                ? null
                : () async {
                    await Navigator.push<bool>(
                      context,
                      MaterialPageRoute<bool>(
                        builder: (_) => const WalletPinPage(),
                      ),
                    );
                    if (mounted) await _load();
                  },
            child: AyoText(hasPin ? 'Kelola' : 'Buat PIN'),
          ),
        ],
      ),
    );
  }

  Widget _heldFundsInfoCard() {
    final num pending = _number(_summary['pending_balance']);
    final num held = _number(_summary['held_balance']);
    final String activeStatus =
        (_summary['active_payout_status'] ?? '').toString().trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E2),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFF2D5A8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.lock_clock_outlined, color: _walletBrown, size: 21),
              SizedBox(width: 8),
              Expanded(
                child: AyoText(
                  'Tentang saldo Pending & Ditahan',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _walletBrown,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AyoText(
            'Pending ${formatRupiah(pending)} adalah pendapatan pekerjaan yang '
            'masih melewati masa hold sebelum menjadi saldo tersedia.',
            style: const TextStyle(fontSize: 11.5, height: 1.45),
          ),
          const SizedBox(height: 7),
          AyoText(
            held > 0
                ? 'Ditahan ${formatRupiah(held)} sedang dikunci untuk proses '
                    'pencairan dan tidak dapat diajukan lagi sampai pencairan '
                    'selesai, ditolak, atau dibatalkan.'
                : 'Saldo Ditahan akan terisi ketika kamu mengajukan pencairan. '
                    'Dana tersebut tidak bisa digunakan kembali selama proses admin berlangsung.',
            style: const TextStyle(fontSize: 11.5, height: 1.45),
          ),
          if (activeStatus.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 17,
                    color: _walletOrange,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: AyoText(
                      'Status pencairan aktif: ${AyoI18n.t(_payoutStatusLabel(activeStatus))}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: _walletBrown,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          AyoText(
            'Jika transaksi direfund setelah pendapatan tercatat, sistem dapat '
            'membuat penyesuaian ledger. Kasus yang dananya sudah masuk proses '
            'pencairan akan ditinjau admin.',
            style: TextStyle(fontSize: 10.5, height: 1.4, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _bankCard() {
    Map<String, dynamic>? bank;
    for (final Map<String, dynamic> account in _bankAccounts) {
      if (account['is_default'] == true) {
        bank = account;
        break;
      }
    }
    bank ??= _bankAccounts.isEmpty ? null : _bankAccounts.first;

    return _whiteCard(
      title: 'Rekening Pencairan',
      icon: Icons.account_balance_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (bank == null)
            const AyoText(
              'Belum ada rekening pencairan. Tambahkan rekening sebelum mengajukan pencairan saldo.',
              style: TextStyle(fontSize: 12, height: 1.4),
            )
          else ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          AyoText(
                            (bank['bank_name'] ?? '').toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          if (bank['is_default'] == true) ...<Widget>[
                            const SizedBox(width: 7),
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: _walletOrange,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      AyoText(
                        _maskAccount(bank['account_number']),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      AyoText(
                        (bank['account_holder'] ?? '').toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AyoText(
                  '${_bankAccounts.length} tersimpan',
                  style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.78)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openBankAccounts,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: AyoText(
                bank == null ? 'Tambah Rekening' : 'Kelola / Ganti Rekening',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _walletBrown,
                side: const BorderSide(color: _walletOrange),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _payoutHistoryCard() {
    return _whiteCard(
      title: 'Riwayat Pencairan',
      icon: Icons.receipt_long_outlined,
      child: Column(
        children: _payouts.take(8).map((Map<String, dynamic> payout) {
          final String status = (payout['status'] ?? '').toString();
          final DateTime? date = DateTime.tryParse(
            (payout['created_at'] ?? '').toString(),
          )?.toLocal();
          return Container(
            margin: const EdgeInsets.only(bottom: 9),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFAF6),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: _payoutStatusBackground(status),
                  child: Icon(
                    _payoutStatusIcon(status),
                    color: _payoutStatusColor(status),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      AyoText(
                        formatRupiah(payout['amount']),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      AyoText(
                        '${AyoI18n.t(_payoutStatusLabel(status))}${date == null ? '' : ' · ${DateFormat('dd MMM, HH:mm').format(date)}'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: _payoutStatusColor(status),
                        ),
                      ),
                    ],
                  ),
                ),
                if (status == 'requested')
                  TextButton(
                    onPressed: _isActionLoading
                        ? null
                        : () => _cancelPayout(payout),
                    child: const AyoText('Batalkan'),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _ledgerCard() {
    return _whiteCard(
      title: 'Mutasi Saldo',
      icon: Icons.swap_vert_rounded,
      child: _ledger.isEmpty
          ? AyoEmptyState(
              compact: true,
              assetPath: 'assets/images/ayos/ayos_earnings.png',
              badgeIcon: Icons.account_balance_wallet_outlined,
              title: AyoI18n.t('Belum ada aktivitas saldo'),
              description: AyoI18n.t(
                'Pendapatan, pencairan, komisi, dan penyesuaian saldo akan muncul di sini.',
              ),
            )
          : Column(
              children: _ledger.take(20).map((Map<String, dynamic> row) {
                final num amount = _number(row['amount']);
                final bool positive = amount >= 0;
                final DateTime? date = DateTime.tryParse(
                  (row['created_at'] ?? '').toString(),
                )?.toLocal();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: positive
                        ? const Color(0xFFE4F1DB)
                        : const Color(0xFFFFE1DE),
                    child: Icon(
                      positive
                          ? Icons.south_west_rounded
                          : Icons.north_east_rounded,
                      color: positive ? _walletGreen : Colors.red.shade700,
                      size: 19,
                    ),
                  ),
                  title: AyoText(
                    _ledgerLabel((row['entry_type'] ?? '').toString()),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: AyoText(
                    '${AyoI18n.t((row['description'] ?? '').toString())}${date == null ? '' : '\n${DateFormat('dd MMM yyyy, HH:mm').format(date)}'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5),
                  ),
                  trailing: AyoText(
                    '${positive ? '+' : '-'}${formatRupiah(amount.abs())}',
                    style: TextStyle(
                      color: positive ? _walletGreen : Colors.red.shade700,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _mockInfoCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBCB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.science_outlined, color: _walletBrown),
          SizedBox(width: 10),
          Expanded(
            child: AyoText(
              'Pencairan saat ini memakai provider mock untuk pengujian. '
              'Saldo dan status tercatat nyata di database, tetapi belum ada '
              'transfer otomatis ke rekening sampai layanan payout Production aktif.',
              style: TextStyle(fontSize: 11.5, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _whiteCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFEEDFD5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: _walletBrown, size: 20),
              const SizedBox(width: 8),
              AyoText(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }

  String _ledgerLabel(String type) {
    switch (type) {
      case 'job_earning':
        return 'Pendapatan Pekerjaan';
      case 'payout_hold':
        return 'Saldo Ditahan';
      case 'payout_release':
        return 'Saldo Dikembalikan';
      case 'payout_paid':
        return 'Pencairan Berhasil';
      case 'refund_adjustment':
        return 'Penyesuaian Refund';
      case 'voucher_subsidy':
        return 'Subsidi Voucher Cash';
      case 'cash_commission':
        return 'Komisi Platform Cash';
      default:
        return 'Penyesuaian Saldo';
    }
  }

  String _payoutStatusLabel(String status) {
    switch (status) {
      case 'requested':
        return 'Menunggu Pemeriksaan';
      case 'under_review':
        return 'Sedang Ditinjau';
      case 'approved':
        return 'Disetujui';
      case 'processing':
        return 'Sedang Dikirim';
      case 'paid':
        return 'Berhasil Dicairkan';
      case 'rejected':
        return 'Ditolak';
      case 'failed':
        return 'Gagal';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  Color _payoutStatusColor(String status) {
    if (status == 'paid') return _walletGreen;
    if (<String>['rejected', 'failed'].contains(status)) {
      return Colors.red.shade700;
    }
    if (status == 'cancelled') return Colors.grey.shade700;
    return _walletOrange;
  }

  Color _payoutStatusBackground(String status) {
    if (status == 'paid') return const Color(0xFFE4F1DB);
    if (<String>['rejected', 'failed'].contains(status)) {
      return const Color(0xFFFFE1DE);
    }
    if (status == 'cancelled') return const Color(0xFFEDE8E5);
    return const Color(0xFFFFEBCB);
  }

  IconData _payoutStatusIcon(String status) {
    if (status == 'paid') return Icons.check_circle_outline_rounded;
    if (<String>['rejected', 'failed'].contains(status)) {
      return Icons.error_outline_rounded;
    }
    if (status == 'cancelled') return Icons.cancel_outlined;
    return Icons.hourglass_top_rounded;
  }
}

class _PayoutFormSheet extends StatefulWidget {
  const _PayoutFormSheet({
    required this.availableBalance,
    required this.minimumPayout,
    required this.bankAccount,
    required this.onSubmit,
  });

  final num availableBalance;
  final num minimumPayout;
  final Map<String, dynamic> bankAccount;
  final Future<void> Function(num amount, String pin) onSubmit;

  @override
  State<_PayoutFormSheet> createState() => _PayoutFormSheetState();
}

class _PayoutFormSheetState extends State<_PayoutFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.availableBalance.floor().toString(),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  num _parseAmount(String value) {
    return num.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  String _mask(Object? raw) {
    final String value = (raw ?? '').toString().trim();
    if (value.length <= 4) return value;
    return '•••• ${value.substring(value.length - 4)}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    final String? pin = await showWalletPinPrompt(
      context,
      title: 'Konfirmasi Pencairan',
      message: 'Masukkan PIN AyoPay sebelum mengajukan pencairan saldo.',
    );
    if (pin == null || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(_parseAmount(_amountController.text), pin);
      if (mounted) Navigator.pop(context, true);
    } on WalletPinException catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(context, error.message);
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(
        context,
        'Pencairan belum dapat diajukan: $error',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> bank = widget.bankAccount;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: _walletBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                AyoText(
                  'Ajukan Pencairan',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: _walletBrown,
                  ),
                ),
                const SizedBox(height: 5),
                AyoText(
                  'Saldo tersedia ${formatRupiah(widget.availableBalance)}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE6DAD2)),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.account_balance_rounded,
                        color: _walletBrown,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            AyoText(
                              (bank['bank_name'] ?? 'Rekening').toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            AyoText(
                              '${_mask(bank['account_number'])} · ${(bank['account_holder'] ?? '').toString()}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  validator: (String? value) {
                    final num amount = _parseAmount(value ?? '');
                    if (amount < widget.minimumPayout) {
                      return 'Minimum ${formatRupiah(widget.minimumPayout)}.';
                    }
                    if (amount > widget.availableBalance) {
                      return 'Nominal melebihi saldo tersedia.';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: AyoI18n.t('Nominal pencairan'),
                    prefixText: 'Rp ',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE6DAD2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: _walletOrange,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _walletBrown,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: const AyoText(
                      'Ajukan Pencairan',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
