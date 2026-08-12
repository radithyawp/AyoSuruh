import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/ayo_snackbar.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../jobs/job_helpers.dart';
import '../refunds/refund_helpers.dart';
import '../refunds/refund_request_page.dart';
import '../refunds/refund_service.dart';
import 'cash_checkout_page.dart';
import 'payment_helpers.dart';
import 'payment_service.dart';
import '../widgets/home_shortcut_button.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';

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
  final RefundService _refundService = RefundService();

  bool _isLoading = true;
  bool _isCreating = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  Map<String, dynamic>? _payment;
  Map<String, dynamic>? _refund;
  List<Map<String, dynamic>> _attempts = <Map<String, dynamic>>[];
  Timer? _pollTimer;
  StreamSubscription<Map<String, dynamic>?>? _paymentSubscription;
  bool _successMessageShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscribeToPayment();
    _loadPayment();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _paymentSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        isPaymentRequired(_payment) &&
        !isCashPayment(_payment)) {
      _refreshStatus(silent: true);
    }
  }

  void _subscribeToPayment() {
    _paymentSubscription = _paymentService
        .watchJobPayment(widget.jobId)
        .listen(
          (Map<String, dynamic>? payment) {
            if (payment == null || !mounted) return;
            _applyPayment(payment, fromRealtime: true);
          },
          onError: (Object error) {
            debugPrint('Realtime pembayaran tidak tersedia: $error');
          },
        );
  }

  Future<void> _loadPayment() async {
    try {
      final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
        _paymentService.fetchJobPayment(widget.jobId),
        _paymentService.fetchJobPaymentAttempts(widget.jobId),
        _refundService.fetchJobRefund(widget.jobId),
      ]);
      if (!mounted) return;
      setState(() {
        _payment = result[0] as Map<String, dynamic>?;
        _attempts = result[1] as List<Map<String, dynamic>>;
        _refund = result[2] as Map<String, dynamic>?;
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

  Future<void> _loadAttempts() async {
    try {
      final List<Map<String, dynamic>> attempts = await _paymentService
          .fetchJobPaymentAttempts(widget.jobId);
      if (!mounted) return;
      setState(() => _attempts = attempts);
    } catch (error) {
      debugPrint('Riwayat percobaan pembayaran gagal dimuat: $error');
    }
  }

  void _applyPayment(
    Map<String, dynamic> payment, {
    bool fromRealtime = false,
  }) {
    final bool wasPaid = isPaymentPaid(_payment);
    final bool nowPaid = isPaymentPaid(payment);
    if (!mounted) return;

    setState(() {
      _payment = payment;
      _errorMessage = null;
      _isLoading = false;
    });
    _configurePolling();

    if (fromRealtime) {
      _loadAttempts();
    }

    if (!wasPaid && nowPaid && !_successMessageShown) {
      _successMessageShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AyoSnackBar.success(context, 'Pembayaran berhasil diverifikasi.');
      });
    }
  }

  void _configurePolling() {
    _pollTimer?.cancel();
    final String status = (_payment?['status'] ?? '').toString().toLowerCase();
    final bool hasOrder = (_payment?['order_id'] ?? '')
        .toString()
        .trim()
        .isNotEmpty;
    if (isCashPayment(_payment) ||
        !isPaymentRequired(_payment) ||
        status != 'pending' ||
        !hasOrder) {
      return;
    }

    _pollTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _refreshStatus(silent: true);
    });
  }

  Future<void> _createTransaction() async {
    if (_isCreating) return;
    setState(() => _isCreating = true);
    try {
      final Map<String, dynamic> result = await _paymentService
          .createSnapTransaction(widget.jobId);
      final dynamic rawPayment = result['payment'];
      final Map<String, dynamic>? payment = rawPayment is Map
          ? Map<String, dynamic>.from(rawPayment)
          : await _paymentService.fetchJobPayment(widget.jobId);
      if (payment != null) {
        _applyPayment(payment);
      }
      await _loadAttempts();
      await _openCheckout();
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(
        context,
        'Transaksi Midtrans belum dapat dibuat: $error',
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
      AyoSnackBar.info(context, 'Tautan pembayaran belum tersedia.');
      return;
    }

    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!opened && mounted) {
      AyoSnackBar.error(context, 'Halaman Midtrans tidak dapat dibuka.');
    }
  }

  Future<void> _openCashCheckout() async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => CashCheckoutPage(
          jobId: widget.jobId,
          jobTitle: widget.jobTitle,
        ),
      ),
    );
    if (!mounted) return;
    await _loadPayment();
    if (changed == true && mounted) {
      AyoSnackBar.success(context, 'Status pembayaran tunai diperbarui.');
    }
  }

  Future<void> _openRefund() async {
    if (_payment == null) return;

    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => RefundRequestPage(
          jobId: widget.jobId,
          jobTitle: widget.jobTitle,
          payment: _payment!,
          initialRefund: _refund,
        ),
      ),
    );

    if (!mounted) return;
    await _loadPayment();
  }

  Future<void> _refreshStatus({bool silent = false}) async {
    final bool hasOrder = (_payment?['order_id'] ?? '')
        .toString()
        .trim()
        .isNotEmpty;
    if (_isRefreshing || !hasOrder) return;

    _isRefreshing = true;
    if (!silent && mounted) setState(() {});
    try {
      final Map<String, dynamic> result = await _paymentService
          .refreshPaymentStatus(widget.jobId);
      final dynamic rawPayment = result['payment'];
      final Map<String, dynamic>? payment = rawPayment is Map
          ? Map<String, dynamic>.from(rawPayment)
          : await _paymentService.fetchJobPayment(widget.jobId);
      if (payment != null) {
        _applyPayment(payment);
      }
      await _loadAttempts();
    } catch (error) {
      if (!silent && mounted) {
        AyoSnackBar.error(
          context,
          'Status belum dapat diperbarui: $error',
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context, isPaymentPaid(_payment)),
          icon: Icon(Icons.arrow_back_rounded, color: paymentBrown),
        ),
        title: AyoText(
          'Pembayaran Pekerjaan',
          style: TextStyle(
            color: paymentBrown,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: const <Widget>[
          HomeShortcutButton(),
        ],
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
                Icons.error_outline_rounded,
                size: 54,
                color: paymentBrown,
              ),
              const SizedBox(height: 12),
              AyoText(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadPayment,
                child: const AyoText('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final bool paid = isPaymentPaid(_payment);
    final bool ended =
        isPaymentRefunded(_payment) || isPaymentCancelled(_payment);
    final bool activeLink = hasActiveMidtransCheckout(_payment);
    final bool cash = isCashPayment(_payment);
    final String status = (_payment?['status'] ?? '').toString().toLowerCase();
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
          if (!cash && _attempts.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            _attemptHistoryCard(),
          ],
          if (!cash && _refund != null) ...<Widget>[
            const SizedBox(height: 16),
            _refundStatusCard(),
          ],
          const SizedBox(height: 16),
          _securityInfoCard(cash: cash),
          const SizedBox(height: 22),
          if (paid) ...<Widget>[
            if (!cash) ...<Widget>[
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _openRefund,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  icon: const Icon(Icons.currency_exchange_rounded),
                  label: AyoText(
                    _refund == null
                        ? 'Ajukan Pembatalan & Refund'
                        : 'Lihat Status Refund',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
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
                label: const AyoText(
                  'Kembali ke Detail Pekerjaan',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ] else if (ended) ...<Widget>[
            if (!cash) ...<Widget>[
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _openRefund,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const AyoText(
                    'Lihat Rincian Refund',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, false),
                style: FilledButton.styleFrom(
                  backgroundColor: paymentBrown,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const AyoText('Kembali ke Detail Pekerjaan'),
              ),
            ),
          ] else ...<Widget>[
            if (cash) ...<Widget>[
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _openCashCheckout,
                  style: FilledButton.styleFrom(
                    backgroundColor: paymentOrange,
                    foregroundColor: paymentDarkBrown,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  icon: const Icon(Icons.payments_rounded),
                  label: const AyoText(
                    'Buka Pembayaran Tunai',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ] else ...<Widget>[
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _openCashCheckout,
                  style: FilledButton.styleFrom(
                    backgroundColor: paymentOrange,
                    foregroundColor: paymentDarkBrown,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  icon: const Icon(Icons.payments_rounded),
                  label: const AyoText(
                    'Bayar Tunai / Cash',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              if (kDebugMode) ...<Widget>[
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isCreating
                        ? null
                        : activeLink
                            ? _openCheckout
                            : _createTransaction,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: paymentBrown,
                      side: const BorderSide(color: paymentOrange),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    icon: _isCreating
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: paymentBrown,
                            ),
                          )
                        : const Icon(Icons.science_outlined),
                    label: AyoText(
                      activeLink
                          ? 'Lanjutkan Midtrans Sandbox'
                          : 'Uji Midtrans Sandbox',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
              if (kDebugMode &&
                  (_payment?['order_id'] ?? '').toString().trim().isNotEmpty &&
                  status == 'pending') ...<Widget>[
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _openRefund,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    icon: const Icon(Icons.cancel_outlined),
                    label: AyoText(
                      _refund == null
                          ? 'Batalkan Transaksi & Pekerjaan'
                          : 'Lihat Permintaan Pembatalan',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
              if (kDebugMode &&
                  (_payment?['order_id'] ?? '').toString().trim().isNotEmpty) ...<Widget>[
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
                        ? SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: paymentBrown,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: const AyoText(
                      'Cek Status Midtrans',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _statusCard() {
    final bool required = isPaymentRequired(_payment);
    final bool paid = isPaymentPaid(_payment);
    final String status = (_payment?['status'] ?? '').toString().toLowerCase();

    String description;
    if (status == 'refunded') {
      description = 'Dana transaksi telah dikembalikan.';
    } else if (status == 'cancelled') {
      description = 'Transaksi dan pekerjaan telah dibatalkan.';
    } else if (isCashPayment(_payment) && paid) {
      description = 'Pembayaran tunai sudah dikonfirmasi dan tercatat di Ayo Suruh.';
    } else if (isCashPayment(_payment)) {
      description = 'Metode tunai sudah dipilih. Bayar langsung ke Mitra setelah pekerjaan selesai.';
    } else if (!required) {
      description = 'Pilih pembayaran Tunai. Midtrans Sandbox hanya tersedia pada debug untuk pengujian.';
    } else if (paid) {
      description = 'Pembayaran terverifikasi. Mitra sekarang dapat memulai pekerjaan.';
    } else if (status == 'expired') {
      description =
          'Waktu pembayaran telah habis. Buat pembayaran baru untuk memperoleh kode atau QR baru.';
    } else if (status == 'failed') {
      description =
          'Percobaan pembayaran sebelumnya gagal. Kamu dapat membuat pembayaran baru.';
    } else {
      description =
          'Selesaikan transaksi melalui halaman aman Midtrans. Status diperbarui otomatis melalui webhook.';
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
          AyoText(
            paymentStatusLabel(_payment),
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          AyoText(
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
    final String method = paymentMethodLabel(_payment?['payment_type']);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: paymentBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AyoText(
            'Rincian Pembayaran',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          AyoText(
            widget.jobTitle,
            style: const TextStyle(color: Color(0xFF6D6059)),
          ),
          const SizedBox(height: 18),
          _priceRow('Harga jasa mitra', formatRupiah(baseAmount)),
          if (serviceFee > 0) ...<Widget>[
            const SizedBox(height: 10),
            _priceRow('Biaya layanan pembayaran', formatRupiah(serviceFee)),
          ],
          if (paymentDiscountAmount(_payment) > 0) ...<Widget>[
            const SizedBox(height: 10),
            _priceRow(
              'Voucher ${(_payment?['voucher_code'] ?? '').toString()}',
              '- ${formatRupiah(paymentDiscountAmount(_payment))}',
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          _priceRow('Total Pembayaran', formatRupiah(total), emphasized: true),
          if ((_payment?['order_id'] ?? '')
              .toString()
              .trim()
              .isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            _detailRow('Order ID', _payment!['order_id'].toString()),
          ],
          if (method.isNotEmpty) ...<Widget>[
            const SizedBox(height: 7),
            _detailRow('Metode', method),
          ],
          if (_payment?['expires_at'] != null) ...<Widget>[
            const SizedBox(height: 7),
            _detailRow('Berlaku sampai', _formatDate(_payment!['expires_at'])),
          ],
          if (_payment?['paid_at'] != null) ...<Widget>[
            const SizedBox(height: 7),
            _detailRow('Dibayar pada', _formatDate(_payment!['paid_at'])),
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
          child: AyoText(
            label,
            style: TextStyle(
              color: emphasized ? Theme.of(context).colorScheme.onSurface : const Color(0xFF6D6059),
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        AyoText(
          value,
          style: TextStyle(
            color: emphasized ? paymentBrown : Theme.of(context).colorScheme.onSurface,
            fontSize: emphasized ? 20 : 14,
            fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 92,
          child: AyoText(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF8A7B72)),
          ),
        ),
        Expanded(
          child: AyoText(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF655A53),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _attemptHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: paymentBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.history_rounded, color: paymentBrown),
              const SizedBox(width: 8),
              const Expanded(
                child: AyoText(
                  'Riwayat Percobaan',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
              AyoText(
                '${_attempts.length} percobaan',
                style: const TextStyle(color: Color(0xFF8A7B72), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._attempts.take(5).map(_attemptTile),
        ],
      ),
    );
  }

  Widget _attemptTile(Map<String, dynamic> attempt) {
    final Map<String, dynamic> statusMap = <String, dynamic>{
      'payment_required': true,
      'status': attempt['status'],
    };
    final String method = paymentMethodLabel(attempt['payment_type']);
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 18,
            backgroundColor: paymentStatusBackground(statusMap),
            child: Icon(
              paymentStatusIcon(statusMap),
              color: paymentStatusColor(statusMap),
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AyoText(
                  paymentStatusLabel(statusMap),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                AyoText(
                  method.isEmpty
                      ? _formatDate(attempt['created_at'])
                      : '$method • ${_formatDate(attempt['created_at'])}',
                  style: const TextStyle(
                    color: Color(0xFF8A7B72),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          AyoText(
            formatRupiah(
              _asNum(attempt['amount']) + _asNum(attempt['service_fee']),
            ),
            style: TextStyle(
              color: paymentBrown,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _refundStatusCard() {
    final Map<String, dynamic> refund = _refund!;
    final Color color = refundStatusColor(refund['status']);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: refundStatusBackground(refund['status']),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(refundStatusIcon(refund['status']), color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AyoText(
                  refundStatusLabel(refund['status']),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                AyoText(
                  (refund['status_message'] ??
                          'Status refund akan diperbarui otomatis.')
                      .toString(),
                  style: const TextStyle(fontSize: 11.5, height: 1.4),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _openRefund,
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 17),
                  label: const AyoText('Buka rincian'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _securityInfoCard({required bool cash}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6EC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.verified_user_outlined, color: paymentGreen),
          const SizedBox(width: 10),
          Expanded(
            child: AyoText(
              cash
                  ? 'Pembayaran tunai dilakukan langsung Customer ke Mitra. Ayo Suruh mencatat nominal, voucher, dan konfirmasi pembayarannya.'
                  : 'Untuk release saat ini, pembayaran tunai tersedia. Midtrans tetap dipertahankan sebagai Sandbox pada debug sampai akun produksi disetujui.',
              style: const TextStyle(
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

  String _formatDate(Object? rawValue) {
    final DateTime? value = DateTime.tryParse(rawValue?.toString() ?? '');
    if (value == null) return '-';
    return DateFormat('dd MMM yyyy, HH:mm').format(value.toLocal());
  }

  num _asNum(Object? value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }
}
