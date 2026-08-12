import 'package:flutter/material.dart';

import '../jobs/job_helpers.dart';
import '../vouchers/voucher_service.dart';
import '../widgets/ayo_snackbar.dart';
import '../widgets/home_shortcut_button.dart';
import 'payment_helpers.dart';
import 'payment_service.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';

class CashCheckoutPage extends StatefulWidget {
  const CashCheckoutPage({
    super.key,
    required this.jobId,
    required this.jobTitle,
  });

  final String jobId;
  final String jobTitle;

  @override
  State<CashCheckoutPage> createState() => _CashCheckoutPageState();
}

class _CashCheckoutPageState extends State<CashCheckoutPage> {
  final PaymentService _paymentService = PaymentService();
  final VoucherService _voucherService = VoucherService();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic>? _payment;
  Map<String, dynamic>? _job;
  List<Map<String, dynamic>> _vouchers = <Map<String, dynamic>>[];
  Map<String, dynamic>? _selectedVoucher;
  Map<String, dynamic>? _preview;

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
      final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
        _paymentService.fetchJobPayment(widget.jobId),
        _paymentService.fetchJobContext(widget.jobId),
        _voucherService.fetchMyVouchers(),
      ]);
      final Map<String, dynamic>? payment = result[0] as Map<String, dynamic>?;
      final List<Map<String, dynamic>> vouchers =
          result[2] as List<Map<String, dynamic>>;
      Map<String, dynamic>? selected;
      final String selectedId =
          (payment?['user_voucher_id'] ?? '').toString().trim();
      if (selectedId.isNotEmpty) {
        for (final Map<String, dynamic> row in vouchers) {
          if ((row['user_voucher_id'] ?? '').toString() == selectedId) {
            selected = row;
            break;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _payment = payment;
        _job = result[1] as Map<String, dynamic>;
        _vouchers = vouchers;
        _selectedVoucher = selected;
        _preview = selected == null
            ? null
            : <String, dynamic>{
                'eligible': true,
                'code': payment?['voucher_code'],
                'discount_amount': paymentDiscountAmount(payment),
                'payable_amount': paymentTotalAmount(payment),
              };
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

  Future<void> _chooseVoucher() async {
    final num subtotal = paymentBaseAmount(_payment);
    final List<Map<String, dynamic>> options = _vouchers.where((row) {
      final String status = (row['status'] ?? '').toString();
      final String currentId = (_payment?['user_voucher_id'] ?? '').toString();
      return status == 'available' ||
          (status == 'reserved' &&
              (row['user_voucher_id'] ?? '').toString() == currentId);
    }).toList();

    final Map<String, dynamic>? choice =
        await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const AyoText(
                  'Pilih Voucher',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                AyoText(
                  'Voucher dihitung dari harga jasa ${formatRupiah(subtotal)}.',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF766A63),
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Color(0xFFF3EEE9),
                    child: Icon(Icons.block_rounded, color: paymentBrown),
                  ),
                  title: const AyoText(
                    'Tanpa Voucher',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    <String, dynamic>{'_none': true},
                  ),
                ),
                if (options.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: AyoText(
                        'Belum ada voucher yang bisa digunakan.',
                        style: TextStyle(color: Color(0xFF766A63)),
                      ),
                    ),
                  )
                else
                  ...options.map((Map<String, dynamic> voucher) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Color(0xFFFFE8C6),
                        child: Icon(
                          Icons.local_activity_rounded,
                          color: paymentBrown,
                        ),
                      ),
                      title: AyoText(
                        (voucher['title'] ?? voucher['code'] ?? 'Voucher')
                            .toString(),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: AyoText(
                        '${_discountText(voucher)} • Min. ${formatRupiah(_asNum(voucher['min_transaction']))}',
                      ),
                      onTap: () => Navigator.pop(sheetContext, voucher),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );

    if (choice == null || !mounted) return;
    if (choice['_none'] == true) {
      setState(() {
        _selectedVoucher = null;
        _preview = null;
      });
      if (isCashPayment(_payment)) await _prepareCash();
      return;
    }

    final String voucherId = (choice['user_voucher_id'] ?? '').toString();
    final String status = (choice['status'] ?? '').toString();
    if (status == 'reserved' &&
        (choice['user_voucher_id'] ?? '').toString() ==
            (_payment?['user_voucher_id'] ?? '').toString()) {
      setState(() {
        _selectedVoucher = choice;
        _preview = <String, dynamic>{
          'eligible': true,
          'code': _payment?['voucher_code'],
          'discount_amount': paymentDiscountAmount(_payment),
          'payable_amount': paymentTotalAmount(_payment),
        };
      });
      return;
    }

    try {
      final Map<String, dynamic> preview = await _voucherService.preview(
        userVoucherId: voucherId,
        subtotal: subtotal,
        jobId: widget.jobId,
      );
      if (!mounted) return;
      if (preview['eligible'] != true) {
        AyoSnackBar.info(
          context,
          (preview['message'] ?? 'Voucher ini belum dapat digunakan.')
              .toString(),
        );
        return;
      }
      setState(() {
        _selectedVoucher = choice;
        _preview = preview;
      });
      if (isCashPayment(_payment)) await _prepareCash();
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(context, 'Voucher belum dapat dipakai: $error');
    }
  }

  Future<void> _prepareCash() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final Map<String, dynamic> payment =
          await _paymentService.prepareCashPayment(
        jobId: widget.jobId,
        userVoucherId:
            (_selectedVoucher?['user_voucher_id'] ?? '').toString().isEmpty
                ? null
                : _selectedVoucher!['user_voucher_id'].toString(),
      );
      if (!mounted) return;
      setState(() {
        _payment = payment;
        _preview = <String, dynamic>{
          'eligible': true,
          'code': payment['voucher_code'],
          'discount_amount': paymentDiscountAmount(payment),
          'payable_amount': paymentTotalAmount(payment),
        };
      });
      await _load();
      if (!mounted) return;
      AyoSnackBar.success(
        context,
        'Pembayaran tunai dipilih. Bayar ke Mitra setelah pekerjaan selesai.',
      );
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(context, 'Pembayaran tunai belum dapat dipilih: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmCash() async {
    final num total = paymentTotalAmount(_payment);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const AyoText('Sudah bayar tunai?'),
          content: AyoText(
            'Pastikan kamu sudah menyerahkan ${formatRupiah(total)} langsung kepada Mitra. Setelah dikonfirmasi, transaksi tunai akan dicatat sebagai dibayar.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const AyoText('Belum'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: paymentGreen),
              child: const AyoText('Sudah Bayar'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || _saving) return;

    setState(() => _saving = true);
    try {
      final Map<String, dynamic> payment =
          await _paymentService.confirmCashPayment(widget.jobId);
      if (!mounted) return;
      setState(() => _payment = payment);
      AyoSnackBar.success(context, 'Pembayaran tunai berhasil dikonfirmasi.');
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(context, 'Pembayaran belum dapat dikonfirmasi: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
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
        title: AyoText(
          'Bayar Tunai',
          style: TextStyle(
            color: paymentBrown,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: const <Widget>[HomeShortcutButton()],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: paymentOrange),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AyoText(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton(onPressed: _load, child: const AyoText('Coba Lagi')),
            ],
          ),
        ),
      );
    }

    final bool cashSelected = isCashPayment(_payment);
    final bool paid = cashSelected && isPaymentPaid(_payment);
    final String progress = (_job?['progress_stage'] ?? '').toString();
    final bool completionSubmitted =
        (_job?['status'] ?? '').toString() == 'on_progress' &&
            progress == 'completion_submitted';
    final num base = paymentBaseAmount(_payment);
    final num previewDiscount = _preview == null
        ? 0
        : _asNum(_preview!['discount_amount']);
    final num discount = cashSelected
        ? paymentDiscountAmount(_payment)
        : previewDiscount;
    final num total = cashSelected
        ? paymentTotalAmount(_payment)
        : (base - discount).clamp(0, base);
    dynamic rawVoucherCode;
    if (cashSelected) {
      rawVoucherCode =
          _payment == null ? null : _payment!['voucher_code'];
    } else {
      rawVoucherCode =
          _preview == null ? null : _preview!['code'];
    }

    final String voucherCode = rawVoucherCode?.toString().trim() ?? '';
    final String voucherLabel =
        voucherCode.isEmpty ? 'Voucher' : 'Voucher $voucherCode';

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 34),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE9CA),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.payments_rounded, color: paymentBrown),
              SizedBox(width: 11),
              Expanded(
                child: AyoText(
                  'Bayar langsung kepada Mitra setelah pekerjaan selesai. Ayo Suruh tetap mencatat transaksi dan penggunaan voucher di aplikasi.',
                  style: TextStyle(fontSize: 11.5, height: 1.45),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const AyoText(
                'Rincian Pembayaran',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              AyoText(
                widget.jobTitle,
                style: const TextStyle(color: Color(0xFF746A64)),
              ),
              const SizedBox(height: 16),
              _row('Harga jasa Mitra', formatRupiah(base)),
              if (discount > 0) ...<Widget>[
                const SizedBox(height: 9),
                _row(
                  voucherLabel,
                  '- ${formatRupiah(discount)}',
                  valueColor: paymentGreen,
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Divider(height: 1),
              ),
              _row(
                'Bayar Tunai',
                formatRupiah(total),
                emphasized: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _card(
          child: Row(
            children: <Widget>[
              const Icon(Icons.local_activity_rounded, color: paymentOrange),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const AyoText(
                      'Voucher',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    AyoText(
                      _selectedVoucher == null
                          ? 'Tanpa voucher'
                          : (_selectedVoucher!['title'] ??
                                  _selectedVoucher!['code'])
                              .toString(),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF746A64),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: paid || _saving ? null : _chooseVoucher,
                child: const AyoText(
                  'Pilih',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (paid)
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: paymentGreen,
            ),
            icon: const Icon(Icons.check_circle_rounded),
            label: const AyoText(
              'Tunai Sudah Dibayar',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          )
        else if (!cashSelected)
          FilledButton.icon(
            onPressed: _saving ? null : _prepareCash,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: paymentOrange,
              foregroundColor: paymentDarkBrown,
            ),
            icon: _saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: paymentDarkBrown,
                    ),
                  )
                : const Icon(Icons.payments_rounded),
            label: const AyoText(
              'Pilih Pembayaran Tunai',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          )
        else if (!completionSubmitted) ...<Widget>[
          FilledButton.icon(
            onPressed: null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.schedule_rounded),
            label: const AyoText('Bayar setelah Mitra menyelesaikan pekerjaan'),
          ),
          const SizedBox(height: 9),
          const AyoText(
            'Metode tunai sudah tersimpan. Mitra tetap dapat memulai pekerjaan meskipun pembayaran belum dikonfirmasi.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: Color(0xFF746A64)),
          ),
        ] else
          FilledButton.icon(
            onPressed: _saving ? null : _confirmCash,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: paymentGreen,
            ),
            icon: const Icon(Icons.task_alt_rounded),
            label: AyoText(
              'Saya Sudah Bayar ${formatRupiah(total)}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: paymentBorder),
      ),
      child: child,
    );
  }

  Widget _row(
    String label,
    String value, {
    bool emphasized = false,
    Color? valueColor,
  }) {
    return Row(
      children: <Widget>[
        Expanded(
          child: AyoText(
            label,
            style: TextStyle(
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
              color: const Color(0xFF675B54),
            ),
          ),
        ),
        AyoText(
          value,
          style: TextStyle(
            color: valueColor ?? (emphasized ? paymentBrown : Theme.of(context).colorScheme.onSurface),
            fontSize: emphasized ? 19 : 13,
            fontWeight: emphasized ? FontWeight.w900 : FontWeight.w800,
          ),
        ),
      ],
    );
  }

  String _discountText(Map<String, dynamic> voucher) {
    final num value = _asNum(voucher['discount_value']);
    if ((voucher['discount_type'] ?? '').toString() == 'percent') {
      return '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}% OFF';
    }
    return '${formatRupiah(value)} OFF';
  }

  num _asNum(Object? value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }
}
