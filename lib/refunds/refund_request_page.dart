import 'package:flutter/material.dart';
import '../widgets/ayo_snackbar.dart';
import 'package:intl/intl.dart';

import '../jobs/job_helpers.dart';
import '../payments/payment_helpers.dart';
import 'refund_helpers.dart';
import 'refund_service.dart';
import '../widgets/home_shortcut_button.dart';

class RefundRequestPage extends StatefulWidget {
  const RefundRequestPage({
    super.key,
    required this.jobId,
    required this.jobTitle,
    required this.payment,
    this.initialRefund,
  });

  final String jobId;
  final String jobTitle;
  final Map<String, dynamic> payment;
  final Map<String, dynamic>? initialRefund;

  @override
  State<RefundRequestPage> createState() => _RefundRequestPageState();
}

class _RefundRequestPageState extends State<RefundRequestPage> {
  final RefundService _service = RefundService();
  final TextEditingController _reasonController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _refund;

  static const List<String> _quickReasons = <String>[
    'Jadwal pekerjaan berubah',
    'Pekerjaan tidak lagi diperlukan',
    'Terjadi kesalahan pemesanan',
    'Kesepakatan dengan mitra dibatalkan',
  ];

  @override
  void initState() {
    super.initState();
    _refund = widget.initialRefund;
    _load();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final Map<String, dynamic>? refund =
          await _service.fetchJobRefund(widget.jobId);
      if (!mounted) return;
      setState(() {
        _refund = refund ?? _refund;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Ajukan pembatalan dan refund?'),
        content: const Text(
          'Jika pekerjaan belum dimulai, sistem akan mencoba membatalkan atau '
          'merefund transaksi melalui Midtrans. Pekerjaan yang sudah berjalan '
          'akan masuk pemeriksaan manual.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Ajukan Refund'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSubmitting = true);
    try {
      final Map<String, dynamic> result = await _service.requestRefund(
        jobId: widget.jobId,
        reason: _reasonController.text,
      );
      final dynamic rawRefund = result['refund'];
      final Map<String, dynamic>? refund = rawRefund is Map
          ? Map<String, dynamic>.from(rawRefund)
          : await _service.fetchJobRefund(widget.jobId);
      if (!mounted) return;
      setState(() => _refund = refund);
      if (result['manual_review'] == true) {
        AyoSnackBar.info(context, 'Permintaan masuk pemeriksaan manual.');
      } else {
        AyoSnackBar.success(context, 'Permintaan refund berhasil diproses.');
      }
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(context, 'Refund belum dapat diproses: $error');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: refundBackground,
      appBar: AppBar(
        backgroundColor: refundBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context, _refund != null),
          icon: const Icon(Icons.arrow_back_rounded, color: refundBrown),
        ),
        title: const Text(
          'Pembatalan & Refund',
          style: TextStyle(
            color: refundBrown,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),

        actions: const <Widget>[HomeShortcutButton()],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: refundOrange))
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
              children: <Widget>[
                _summaryCard(),
                const SizedBox(height: 14),
                if (_refund != null)
                  _statusCard(_refund!)
                else
                  _requestForm(),
                const SizedBox(height: 14),
                _infoCard(),
              ],
            ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEAD8CB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Transaksi yang Dibatalkan',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(widget.jobTitle),
          const SizedBox(height: 14),
          _row('Order ID', (widget.payment['order_id'] ?? '-').toString()),
          const SizedBox(height: 8),
          _row('Status', paymentStatusLabel(widget.payment)),
          const SizedBox(height: 8),
          _row(
            'Total',
            formatRupiah(paymentTotalAmount(widget.payment)),
            emphasized: true,
          ),
        ],
      ),
    );
  }

  Widget _requestForm() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEAD8CB)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Alasan Pembatalan',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickReasons
                  .map(
                    (String reason) => ActionChip(
                      label: Text(reason),
                      onPressed: () {
                        _reasonController.text = reason;
                        setState(() {});
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _reasonController,
              maxLines: 4,
              maxLength: 255,
              decoration: InputDecoration(
                hintText: 'Jelaskan alasan refund minimal 10 karakter...',
                filled: true,
                fillColor: const Color(0xFFFFFBF8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFEAD8CB)),
                ),
              ),
              validator: (String? value) {
                if ((value ?? '').trim().length < 10) {
                  return 'Alasan minimal 10 karakter.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
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
                    : const Icon(Icons.currency_exchange_rounded),
                label: const Text(
                  'Ajukan Pembatalan & Refund',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(Map<String, dynamic> refund) {
    final Color color = refundStatusColor(refund['status']);
    final String? requestedAt = refund['requested_at']?.toString();
    final DateTime? date = requestedAt == null
        ? null
        : DateTime.tryParse(requestedAt)?.toLocal();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: refundStatusBackground(refund['status']),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: <Widget>[
          Icon(refundStatusIcon(refund['status']), color: color, size: 40),
          const SizedBox(height: 12),
          Text(
            refundStatusLabel(refund['status']),
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            (refund['status_message'] ??
                    'Status permintaan akan diperbarui otomatis.')
                .toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, height: 1.45),
          ),
          const SizedBox(height: 14),
          _row('Nominal', formatRupiah(refund['amount'])),
          const SizedBox(height: 7),
          _row('Alasan', (refund['reason'] ?? '-').toString()),
          if (date != null) ...<Widget>[
            const SizedBox(height: 7),
            _row('Diajukan', DateFormat('dd MMM yyyy, HH:mm').format(date)),
          ],
        ],
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBCB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline_rounded, color: refundBrown),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Transaksi pending akan dibatalkan. Transaksi settlement akan '
              'direfund jika metode pembayaran dan akun merchant mendukungnya. '
              'Pekerjaan yang sudah berjalan membutuhkan pemeriksaan manual.',
              style: TextStyle(fontSize: 12, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool emphasized = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF81756E)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: emphasized ? 16 : 11,
              fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
              color: emphasized ? refundBrown : const Color(0xFF554B46),
            ),
          ),
        ),
      ],
    );
  }
}
