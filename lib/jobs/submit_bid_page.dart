import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'job_helpers.dart';
import 'job_service.dart';
import '../widgets/home_shortcut_button.dart';

class SubmitBidPage extends StatefulWidget {
  const SubmitBidPage({
    super.key,
    required this.jobId,
    required this.jobTitle,
    required this.initialBudget,
  });

  final String jobId;
  final String jobTitle;
  final dynamic initialBudget;

  @override
  State<SubmitBidPage> createState() => _SubmitBidPageState();
}

class _SubmitBidPageState extends State<SubmitBidPage> {
  final JobService _jobService = JobService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _estimatedController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isSubmitting = false;
  num _platformFeePercent = 6;

  @override
  void initState() {
    super.initState();
    final num budget = widget.initialBudget is num
        ? widget.initialBudget as num
        : num.tryParse(widget.initialBudget?.toString() ?? '') ?? 0;
    if (budget > 0) _priceController.text = budget.round().toString();
    _priceController.addListener(_refreshEconomics);
    _loadPlatformFee();
  }

  void _refreshEconomics() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPlatformFee() async {
    final num value = await _jobService.fetchPlatformFeePercent();
    if (!mounted) return;
    setState(() => _platformFeePercent = value);
  }

  num get _currentOffer => num.tryParse(_priceController.text) ?? 0;

  num get _platformFeeAmount =>
      (_currentOffer * _platformFeePercent / 100).round();

  num get _estimatedNetAmount =>
      (_currentOffer - _platformFeeAmount).clamp(0, double.infinity);

  @override
  void dispose() {
    _priceController.removeListener(_refreshEconomics);
    _priceController.dispose();
    _estimatedController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final num price = num.tryParse(_priceController.text) ?? 0;

    setState(() => _isSubmitting = true);
    try {
      await _jobService.submitBid(
        jobId: widget.jobId,
        price: price,
        estimatedTime: _estimatedController.text,
        message: _messageController.text,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            icon: const CircleAvatar(
              radius: 28,
              backgroundColor: Color(0xFFDDEED2),
              child: Icon(Icons.check_rounded, color: jobGreenColor, size: 32),
            ),
            title: const Text(
              'Penawaran Terkirim',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            content: const Text(
              'Customer akan melihat harga dan pesanmu. Status pengajuan dapat dipantau pada tab Pengajuan.',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: <Widget>[
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(backgroundColor: jobOrangeColor),
                child: const Text('Selesai'),
              ),
            ],
          );
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Penawaran belum berhasil dikirim: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: jobBackgroundColor,
      appBar: AppBar(
        backgroundColor: jobBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: jobBrownColor),
        ),
        title: const Text(
          'Ajukan Penawaran',
          style: TextStyle(
            color: jobBrownColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),

        actions: const <Widget>[HomeShortcutButton()],
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE4BF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'PEKERJAAN',
                      style: TextStyle(
                        fontSize: 10,
                        color: jobDarkBrownColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.jobTitle,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Budget customer: ${formatRupiah(widget.initialBudget)}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF72512A)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _label('Harga Penawaran'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (String? value) {
                  final num amount = num.tryParse(value ?? '') ?? 0;
                  if (amount < 1000) return 'Harga penawaran minimal Rp 1.000.';
                  return null;
                },
                decoration: _inputDecoration('0', prefixText: 'Rp '),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E3),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFD99C)),
                ),
                child: Column(
                  children: <Widget>[
                    _economicsRow(
                      'Harga penawaran',
                      formatRupiah(_currentOffer),
                    ),
                    const SizedBox(height: 7),
                    _economicsRow(
                      'Komisi Ayo Suruh ${_platformFeePercent.toStringAsFixed(_platformFeePercent % 1 == 0 ? 0 : 1)}%',
                      '-${formatRupiah(_platformFeeAmount)}',
                    ),
                    const Divider(height: 18),
                    _economicsRow(
                      'Estimasi masuk dompet',
                      formatRupiah(_estimatedNetAmount),
                      emphasize: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Komisi platform disnapshot saat transaksi dibuat. Biaya pencairan, jika ada, ditampilkan terpisah ketika withdraw.',
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.35,
                  color: Color(0xFF7A6A5F),
                ),
              ),
              const SizedBox(height: 18),
              _label('Estimasi Waktu Pengerjaan'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _estimatedController,
                textInputAction: TextInputAction.next,
                validator: (String? value) {
                  if (value == null || value.trim().length < 3) {
                    return 'Contoh: 2 jam atau selesai hari ini.';
                  }
                  return null;
                },
                decoration: _inputDecoration('Contoh: 2 jam'),
              ),
              const SizedBox(height: 18),
              _label('Pesan untuk Customer'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _messageController,
                minLines: 4,
                maxLines: 6,
                validator: (String? value) {
                  if (value == null || value.trim().length < 10) {
                    return 'Jelaskan kesiapanmu minimal 10 karakter.';
                  }
                  return null;
                },
                decoration: _inputDecoration(
                  'Perkenalkan diri, jelaskan kesiapan, pengalaman, atau perlengkapan yang kamu miliki...',
                ),
              ),
              const SizedBox(height: 10),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.info_outline_rounded, size: 16, color: jobBrownColor),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Satu mitra hanya dapat mengirim satu penawaran untuk setiap pekerjaan.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF766A62)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: jobOrangeColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text(
                    'Kirim Penawaran',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _economicsRow(
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: emphasize ? 12 : 11,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
              color: const Color(0xFF66584F),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 13 : 11.5,
            fontWeight: FontWeight.w800,
            color: emphasize ? jobGreenColor : jobDarkBrownColor,
          ),
        ),
      ],
    );
  }

  Widget _label(String value) {
    return Text(
      value,
      style: const TextStyle(
        color: jobBrownColor,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {String? prefixText}) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: jobBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: jobOrangeColor, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
      ),
    );
  }
}
