import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../jobs/job_helpers.dart';
import 'job_payment_page.dart';
import 'payment_helpers.dart';
import 'payment_service.dart';
import '../widgets/home_shortcut_button.dart';
import '../widgets/ayo_empty_state.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';

class PaymentHistoryPage extends StatefulWidget {
  const PaymentHistoryPage({super.key});

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  final PaymentService _paymentService = PaymentService();

  bool _isLoading = true;
  String? _errorMessage;
  String _filter = 'all';
  List<Map<String, dynamic>> _payments = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    try {
      final List<Map<String, dynamic>> rows =
          await _paymentService.fetchMyPaymentHistory();
      if (!mounted) return;
      setState(() {
        _payments = rows;
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredPayments {
    if (_filter == 'all') return _payments;
    return _payments.where((Map<String, dynamic> row) {
      return (row['payment_status'] ?? '').toString().toLowerCase() == _filter;
    }).toList();
  }

  Future<void> _openPayment(Map<String, dynamic> payment) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => JobPaymentPage(
          jobId: payment['job_id'].toString(),
          jobTitle: (payment['job_title'] ?? 'Pekerjaan').toString(),
        ),
      ),
    );
    await _loadPayments();
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
          icon: Icon(Icons.arrow_back_rounded, color: paymentBrown),
        ),
        title: AyoText(
          'Riwayat Transaksi',
          style: TextStyle(
            color: paymentBrown,
            fontSize: 20,
            fontWeight: FontWeight.w900,
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
        child: CircularProgressIndicator(color: paymentOrange),
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
                Icons.receipt_long_outlined,
                size: 58,
                color: paymentBrown,
              ),
              const SizedBox(height: 12),
              AyoText(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadPayments,
                child: const AyoText('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: paymentOrange,
      onRefresh: _loadPayments,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: <Widget>[
          _summaryCard(),
          const SizedBox(height: 14),
          _filterBar(),
          const SizedBox(height: 14),
          if (_filteredPayments.isEmpty)
            _emptyState()
          else
            ..._filteredPayments.map(_paymentCard),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    num paidTotal = 0;
    int paidCount = 0;
    int pendingCount = 0;
    for (final Map<String, dynamic> row in _payments) {
      final String status =
          (row['payment_status'] ?? '').toString().toLowerCase();
      if (status == 'paid') {
        paidTotal += _asNum(row['total']);
        paidCount++;
      } else if (status == 'pending') {
        pendingCount++;
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFFFE1B5), Color(0xFFFFF3DE)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0C990)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.account_balance_wallet_rounded, color: paymentBrown),
              SizedBox(width: 8),
              AyoText(
                'Ringkasan Pembayaran',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AyoText(
            formatRupiah(paidTotal),
            style: TextStyle(
              color: paymentBrown,
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          AyoText(
            '$paidCount transaksi berhasil • $pendingCount menunggu pembayaran',
            style: const TextStyle(
              color: Color(0xFF6D5A4E),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    const List<Map<String, String>> filters = <Map<String, String>>[
      <String, String>{'value': 'all', 'label': 'Semua'},
      <String, String>{'value': 'pending', 'label': 'Menunggu'},
      <String, String>{'value': 'paid', 'label': 'Berhasil'},
      <String, String>{'value': 'failed', 'label': 'Gagal'},
      <String, String>{'value': 'expired', 'label': 'Kedaluwarsa'},
      <String, String>{'value': 'refunded', 'label': 'Refund'},
      <String, String>{'value': 'cancelled', 'label': 'Dibatalkan'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((Map<String, String> item) {
          final String value = item['value']!;
          final bool selected = value == _filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: selected,
              onSelected: (_) => setState(() => _filter = value),
              label: AyoText(item['label']!),
              selectedColor: const Color(0xFFFFD99F),
              backgroundColor: Theme.of(context).colorScheme.surface,
              side: BorderSide(
                color: selected ? paymentOrange : paymentBorder,
              ),
              labelStyle: TextStyle(
                color: selected ? paymentBrown : const Color(0xFF6D6059),
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _paymentCard(Map<String, dynamic> payment) {
    final String status =
        (payment['payment_status'] ?? 'pending').toString().toLowerCase();
    final Map<String, dynamic> statusMap = <String, dynamic>{
      'status': status,
      'payment_required': true,
    };
    final String method = paymentMethodLabel(payment['payment_type']);
    final int attempts = int.tryParse(
          (payment['attempt_count'] ?? 0).toString(),
        ) ??
        0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openPayment(payment),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: paymentBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  radius: 25,
                  backgroundColor: paymentStatusBackground(statusMap),
                  backgroundImage:
                      (payment['mitra_avatar_url'] ?? '').toString().isNotEmpty
                          ? NetworkImage(payment['mitra_avatar_url'].toString())
                          : null,
                  child: (payment['mitra_avatar_url'] ?? '').toString().isEmpty
                      ? Icon(
                          paymentStatusIcon(statusMap),
                          color: paymentStatusColor(statusMap),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: AyoText(
                              (payment['job_title'] ?? 'Pekerjaan').toString(),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          AyoText(
                            formatRupiah(payment['total']),
                            style: TextStyle(
                              color: paymentBrown,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      AyoText(
                        (payment['mitra_name'] ?? 'Mitra Ayo Suruh').toString(),
                        style: const TextStyle(
                          color: Color(0xFF6D6059),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: <Widget>[
                          _badge(
                            paymentStatusLabel(statusMap),
                            paymentStatusBackground(statusMap),
                            paymentStatusColor(statusMap),
                          ),
                          if (method.isNotEmpty)
                            _badge(
                              method,
                              const Color(0xFFF1ECE8),
                              const Color(0xFF655A53),
                            ),
                          if (attempts > 1)
                            _badge(
                              '$attempts percobaan',
                              const Color(0xFFF1ECE8),
                              const Color(0xFF655A53),
                            ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      AyoText(
                        _formatDate(
                          payment['paid_at'] ??
                              payment['updated_at'] ??
                              payment['created_at'],
                        ),
                        style: const TextStyle(
                          color: Color(0xFF9A8B82),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF9A8B82),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: AyoText(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return const AyoEmptyState(
      compact: true,
      assetPath: 'assets/images/ayos/ayos_empty.png',
      badgeIcon: Icons.receipt_long_outlined,
      title: 'Belum ada transaksi',
      description: 'Transaksi yang sesuai filter akan tampil di sini.',
    );
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
