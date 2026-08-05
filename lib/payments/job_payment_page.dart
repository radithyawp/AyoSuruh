import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../jobs/job_helpers.dart';
import 'payment_helpers.dart';
import 'payment_service.dart';

class JobPaymentPage extends StatefulWidget {
  const JobPaymentPage({
    super.key,
    required this.jobId,
    required this.jobTitle,
  });

  final String jobId;
  final String jobTitle;

  @override
  State<JobPaymentPage> createState() => _JobPaymentPageState();
}

class _JobPaymentPageState extends State<JobPaymentPage>
    with WidgetsBindingObserver {
  final PaymentService _paymentService = PaymentService();

  bool _isLoading = true;
  bool _isCreating = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  Map<String, dynamic>? _payment;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPayment();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isPaymentRequired(_payment)) {
      _refreshStatus(silent: true);
    }
  }

  Future<void> _loadPayment() async {
    try {
      final Map<String, dynamic>? payment =
          await _paymentService.fetchJobPayment(widget.jobId);
      if (!mounted) return;
      setState(() {
        _payment = payment;
        _errorMessage = null;
        _isLoading = false;
      });
      _configurePolling();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  void _configurePolling() {
    _pollTimer?.cancel();
    final String status = (_payment?['status'] ?? '').toString().toLowerCase();
    final bool hasOrder =
        (_payment?['order_id'] ?? '').toString().trim().isNotEmpty;
    if (!isPaymentRequired(_payment) || status != 'pending' || !hasOrder) {
      return;
    }

    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _refreshStatus(silent: true);
    });
  }

  Future<void> _createTransaction() async {
    if (_isCreating) return;
    setState(() => _isCreating = true);
    try {
      final Map<String, dynamic> result =
          await _paymentService.createSnapTransaction(widget.jobId);
      final dynamic rawPayment = result['payment'];
      if (rawPayment is Map) {
        _payment = Map<String, dynamic>.from(rawPayment);
      } else {
        _payment = await _paymentService.fetchJobPayment(widget.jobId);
      }
      if (!mounted) return;
      setState(() => _errorMessage = null);
      _configurePolling();
      await _openCheckout();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaksi Midtrans belum dapat dibuat: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _openCheckout() async {
    final String rawUrl = (_payment?['redirect_url'] ?? '').toString();
    final Uri? uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tautan pembayaran belum tersedia.')),
      );
      return;
    }

    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Halaman Midtrans tidak dapat dibuka.')),
      );
    }
  }

  Future<void> _refreshStatus({bool silent = false}) async {
    final bool hasOrder =
        (_payment?['order_id'] ?? '').toString().trim().isNotEmpty;
    if (_isRefreshing || !hasOrder) return;

    _isRefreshing = true;
    if (!silent && mounted) setState(() {});
    try {
      final Map<String, dynamic> result =
          await _paymentService.refreshPaymentStatus(widget.jobId);
      final dynamic rawPayment = result['payment'];
      final Map<String, dynamic>? payment = rawPayment is Map
          ? Map<String, dynamic>.from(rawPayment)
          : await _paymentService.fetchJobPayment(widget.jobId);
      if (!mounted) return;
      setState(() {
        _payment = payment;
        _errorMessage = null;
      });
      _configurePolling();
    } catch (error) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status belum dapat diperbarui: $error'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      _isRefreshing = false;
      if (!silent && mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: paymentBackground,
      appBar: AppBar(
        backgroundColor: paymentBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context, isPaymentPaid(_payment)),
          icon: const Icon(Icons.arrow_back_rounded, color: paymentBrown),
        ),
        title: const Text(
          'Pembayaran Midtrans',
          style: TextStyle(
            color: paymentBrown,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
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
              const Icon(
                Icons.error_outline_rounded,
                size: 54,
                color: paymentBrown,
              ),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadPayment, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      );
    }

    final bool required = isPaymentRequired(_payment);
    final bool paid = isPaymentPaid(_payment);
    final bool activeLink = hasActiveMidtransCheckout(_payment);
    final num baseAmount = paymentBaseAmount(_payment);
    final num serviceFee = paymentServiceFee(_payment);
    final num total = paymentTotalAmount(_payment);

    return RefreshIndicator(
      color: paymentOrange,
      onRefresh: () async {
        if ((_payment?['order_id'] ?? '').toString().trim().isEmpty) {
          await _loadPayment();
        } else {
          await _refreshStatus(silent: false);
        }
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
        children: <Widget>[
          _statusCard(),
          const SizedBox(height: 16),
          _summaryCard(
            baseAmount: baseAmount,
            serviceFee: serviceFee,
            total: total,
          ),
          const SizedBox(height: 16),
          _stageInfoCard(),
          const SizedBox(height: 22),
          if (paid)
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: paymentGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text(
                  'Kembali ke Detail Pekerjaan',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            )
          else ...<Widget>[
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _isCreating
                    ? null
                    : activeLink
                        ? _openCheckout
                        : _createTransaction,
                style: FilledButton.styleFrom(
                  backgroundColor: paymentOrange,
                  foregroundColor: paymentDarkBrown,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                icon: _isCreating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: paymentDarkBrown,
                        ),
                      )
                    : Icon(
                        activeLink
                            ? Icons.open_in_new_rounded
                            : Icons.payments_outlined,
                      ),
                label: Text(
                  activeLink
                      ? 'Lanjutkan Pembayaran'
                      : required
                          ? 'Buat Ulang Pembayaran'
                          : 'Aktifkan Pembayaran Midtrans',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            if ((_payment?['order_id'] ?? '').toString().trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isRefreshing ? null : () => _refreshStatus(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: paymentBrown,
                    side: const BorderSide(color: paymentOrange),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  icon: _isRefreshing
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: paymentBrown,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: const Text(
                    'Cek Status Pembayaran',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _statusCard() {
    final bool required = isPaymentRequired(_payment);
    final bool paid = isPaymentPaid(_payment);

    String description;
    if (!required) {
      description =
          'Fondasi pembayaran sudah terpasang. Tombol di bawah baru akan berhasil setelah Server Key Sandbox Midtrans disimpan dan Edge Function di-deploy.';
    } else if (paid) {
      description =
          'Pembayaran terverifikasi. Mitra sekarang dapat memulai pekerjaan.';
    } else {
      description =
          'Selesaikan transaksi melalui halaman aman Midtrans. Status akan diperbarui melalui webhook atau tombol cek status.';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: paymentStatusBackground(_payment),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            paymentStatusIcon(_payment),
            color: paymentStatusColor(_payment),
            size: 38,
          ),
          const SizedBox(height: 14),
          Text(
            paymentStatusLabel(_payment),
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Color(0xFF6D6059),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required num baseAmount,
    required num serviceFee,
    required num total,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: paymentBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Rincian Pembayaran',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(widget.jobTitle, style: const TextStyle(color: Color(0xFF6D6059))),
          const SizedBox(height: 18),
          _priceRow('Harga jasa mitra', formatRupiah(baseAmount)),
          const SizedBox(height: 10),
          _priceRow('Biaya layanan', formatRupiah(serviceFee)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          _priceRow(
            'Total Pembayaran',
            formatRupiah(total),
            emphasized: true,
          ),
          if ((_payment?['order_id'] ?? '').toString().trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              'Order ID: ${_payment!['order_id']}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF8A7B72)),
            ),
          ],
          if (_payment?['expires_at'] != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Berlaku sampai ${_formatExpiry(_payment!['expires_at'])}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF8A7B72)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value, {bool emphasized = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: emphasized ? Colors.black87 : const Color(0xFF6D6059),
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: emphasized ? paymentBrown : Colors.black87,
            fontSize: emphasized ? 20 : 14,
            fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _stageInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6EC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.verified_user_outlined, color: paymentGreen),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Server Key Midtrans tidak disimpan di Flutter. Pembuatan Snap Token, pengecekan status, dan webhook diproses melalui Supabase Edge Functions.',
              style: TextStyle(
                fontSize: 11,
                height: 1.45,
                color: Color(0xFF526347),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatExpiry(Object? rawValue) {
    final DateTime? value = DateTime.tryParse(rawValue?.toString() ?? '');
    if (value == null) return '-';
    return DateFormat('dd MMM yyyy, HH:mm').format(value.toLocal());
  }
}
