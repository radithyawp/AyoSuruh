import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../jobs/job_helpers.dart';
import 'wallet_service.dart';

const Color _walletBrown = Color(0xFF8A5300);
const Color _walletOrange = Color(0xFFFF9800);
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
      ]);
      if (!mounted) return;
      setState(() {
        _summary = result[0] as Map<String, dynamic>;
        _ledger = result[1] as List<Map<String, dynamic>>;
        _payouts = result[2] as List<Map<String, dynamic>>;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saldo tersedia belum mencapai minimum ${formatRupiah(minimum)}.',
          ),
        ),
      );
      return;
    }
    if (_summary['active_payout_id'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masih ada pencairan yang sedang diproses.'),
        ),
      );
      return;
    }

    final bool? requested = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _PayoutFormSheet(
        availableBalance: available,
        minimumPayout: minimum,
        initialBankName: (_summary['bank_name'] ?? '').toString(),
        initialAccountNumber: (_summary['account_number'] ?? '').toString(),
        initialAccountHolder: (_summary['account_holder'] ?? '').toString(),
        onSubmit: (num amount, String bank, String number, String holder) async {
          await _service.requestPayout(
            amount: amount,
            bankName: bank,
            accountNumber: number,
            accountHolder: holder,
          );
        },
      ),
    );
    if (requested == true) await _load();
  }

  Future<void> _cancelPayout(Map<String, dynamic> payout) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Batalkan pencairan?'),
        content: const Text(
          'Saldo yang sedang ditahan akan dikembalikan ke saldo tersedia.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Batalkan Pencairan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isActionLoading = true);
    try {
      await _service.cancelPayout(payout['id'].toString());
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pencairan berhasil dibatalkan.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pencairan belum dapat dibatalkan: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _walletBackground,
      appBar: AppBar(
        backgroundColor: _walletBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.arrow_back_rounded, color: _walletBrown),
        ),
        title: const Text(
          'Dompet Mitra',
          style: TextStyle(
            color: _walletBrown,
            fontWeight: FontWeight.w800,
            fontSize: 19,
          ),
        ),
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
              const Icon(
                Icons.account_balance_wallet_outlined,
                size: 54,
                color: _walletBrown,
              ),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton(onPressed: _load, child: const Text('Coba Lagi')),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF8A5300), Color(0xFFB87516)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'SALDO TERSEDIA',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            formatRupiah(available),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
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
              label: Text(
                'Cairkan Saldo · Min. ${formatRupiah(minimum)}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
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
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
                Text(
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

  Widget _bankCard() {
    final String bank = (_summary['bank_name'] ?? '').toString();
    final String number = (_summary['account_number'] ?? '').toString();
    final String holder = (_summary['account_holder'] ?? '').toString();
    return _whiteCard(
      title: 'Rekening Pencairan',
      icon: Icons.account_balance_outlined,
      child: bank.isEmpty || number.isEmpty
          ? const Text(
              'Data rekening belum tersedia. Isi rekening ketika mengajukan pencairan.',
              style: TextStyle(fontSize: 12, height: 1.4),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  bank,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(number, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  holder,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
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
          final DateTime? date =
              DateTime.tryParse((payout['created_at'] ?? '').toString())?.toLocal();
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
                      Text(
                        formatRupiah(payout['amount']),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        '${_payoutStatusLabel(status)}${date == null ? '' : ' · ${DateFormat('dd MMM, HH:mm').format(date)}'}',
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
                    child: const Text('Batalkan'),
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
          ? const Text(
              'Belum ada pendapatan yang masuk ke dompet.',
              style: TextStyle(fontSize: 12),
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
                      positive ? Icons.south_west_rounded : Icons.north_east_rounded,
                      color: positive ? _walletGreen : Colors.red.shade700,
                      size: 19,
                    ),
                  ),
                  title: Text(
                    _ledgerLabel((row['entry_type'] ?? '').toString()),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${(row['description'] ?? '').toString()}${date == null ? '' : '\n${DateFormat('dd MMM yyyy, HH:mm').format(date)}'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5),
                  ),
                  trailing: Text(
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
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.science_outlined, color: _walletBrown),
          SizedBox(width: 10),
          Expanded(
            child: Text(
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
        color: Colors.white,
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
              Text(
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
    if (<String>['rejected', 'failed'].contains(status)) return Colors.red.shade700;
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
    required this.initialBankName,
    required this.initialAccountNumber,
    required this.initialAccountHolder,
    required this.onSubmit,
  });

  final num availableBalance;
  final num minimumPayout;
  final String initialBankName;
  final String initialAccountNumber;
  final String initialAccountHolder;
  final Future<void> Function(
    num amount,
    String bank,
    String accountNumber,
    String accountHolder,
  ) onSubmit;

  @override
  State<_PayoutFormSheet> createState() => _PayoutFormSheetState();
}

class _PayoutFormSheetState extends State<_PayoutFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _bankController;
  late final TextEditingController _accountController;
  late final TextEditingController _holderController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.availableBalance.floor().toString(),
    );
    _bankController = TextEditingController(text: widget.initialBankName);
    _accountController = TextEditingController(text: widget.initialAccountNumber);
    _holderController = TextEditingController(text: widget.initialAccountHolder);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _bankController.dispose();
    _accountController.dispose();
    _holderController.dispose();
    super.dispose();
  }

  num _parseAmount(String value) {
    return num.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(
        _parseAmount(_amountController.text),
        _bankController.text,
        _accountController.text,
        _holderController.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pencairan belum dapat diajukan: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                const Text(
                  'Ajukan Pencairan',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: _walletBrown,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Saldo tersedia ${formatRupiah(widget.availableBalance)}',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 18),
                _field(
                  controller: _amountController,
                  label: 'Nominal pencairan',
                  keyboardType: TextInputType.number,
                  prefixText: 'Rp ',
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
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _bankController,
                  label: 'Nama bank/e-wallet',
                  validator: _required,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _accountController,
                  label: 'Nomor rekening/akun',
                  keyboardType: TextInputType.number,
                  validator: _required,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _holderController,
                  label: 'Nama pemilik rekening',
                  validator: _required,
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
                    label: const Text(
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

  String? _required(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Wajib diisi.';
    return null;
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? prefixText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEEDFD5)),
        ),
      ),
    );
  }
}
