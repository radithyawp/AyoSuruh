import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../jobs/job_helpers.dart';
import '../jobs/job_service.dart';
import 'mitra_service_service.dart';
import '../widgets/home_shortcut_button.dart';

class CreateMitraServicePage extends StatefulWidget {
  const CreateMitraServicePage({
    super.key,
    this.existingService,
  });

  final Map<String, dynamic>? existingService;

  @override
  State<CreateMitraServicePage> createState() => _CreateMitraServicePageState();
}

class _CreateMitraServicePageState extends State<CreateMitraServicePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final JobService _jobService = JobService();
  final MitraServiceService _service = MitraServiceService();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;

  List<Map<String, dynamic>> _categories = <Map<String, dynamic>>[];
  String? _categoryId;
  bool _loading = true;
  bool _saving = false;

  bool get _isEditing => widget.existingService != null;

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic>? existing = widget.existingService;
    _titleController = TextEditingController(
      text: (existing?['title'] ?? '').toString(),
    );
    _descriptionController = TextEditingController(
      text: (existing?['description'] ?? '').toString(),
    );
    final num price = existing?['starting_price'] is num
        ? existing!['starting_price'] as num
        : num.tryParse(existing?['starting_price']?.toString() ?? '') ?? 0;
    _priceController = TextEditingController(
      text: price > 0 ? price.round().toString() : '',
    );
    _categoryId = existing?['category_id']?.toString();
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final List<Map<String, dynamic>> categories =
          await _jobService.fetchCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        if (_categoryId == null && categories.isNotEmpty) {
          _categoryId = categories.first['id'].toString();
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Kategori belum dapat dimuat: $error', error: true);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final String? categoryId = _categoryId;
    if (categoryId == null) {
      _showMessage('Pilih kategori jasa.', error: true);
      return;
    }

    final num price = num.tryParse(
          _priceController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await _service.updateService(
          serviceId: widget.existingService!['id'].toString(),
          categoryId: categoryId,
          title: _titleController.text,
          description: _descriptionController.text,
          startingPrice: price,
        );
      } else {
        await _service.createService(
          categoryId: categoryId,
          title: _titleController.text,
          description: _descriptionController.text,
          startingPrice: price,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      _showMessage('Jasa belum dapat disimpan: $error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : jobGreenColor,
      ),
    );
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
          onPressed: _saving ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: jobBrownColor),
        ),
        title: Text(
          _isEditing ? 'Edit Jasa' : 'Tambah Jasa',
          style: const TextStyle(
            color: jobBrownColor,
            fontWeight: FontWeight.w900,
          ),
        ),

        actions: const <Widget>[HomeShortcutButton()],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: jobOrangeColor),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 34),
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBCB),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(Icons.storefront_rounded, color: jobBrownColor),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Jasa ini akan tampil saat customer mencari layanan. Ketika dipesan, customer tetap membuat pekerjaan melalui alur Ayo Suruh.',
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.45,
                              color: Color(0xFF6A574B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Kategori',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    items: _categories
                        .map(
                          (Map<String, dynamic> category) =>
                              DropdownMenuItem<String>(
                            value: category['id'].toString(),
                            child: Text(
                              (category['name'] ?? 'Lainnya').toString(),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (String? value) => setState(() => _categoryId = value),
                    decoration: _decoration('Pilih kategori'),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Nama Jasa',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    decoration: _decoration(
                      'Contoh: Jasa desain poster dan konten Instagram',
                    ),
                    validator: (String? value) =>
                        (value ?? '').trim().length < 5
                            ? 'Nama jasa minimal 5 karakter.'
                            : null,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Deskripsi Keahlian',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 5,
                    decoration: _decoration(
                      'Jelaskan cakupan jasa, kemampuan, dan hal yang perlu diketahui customer.',
                    ),
                    validator: (String? value) =>
                        (value ?? '').trim().length < 10
                            ? 'Deskripsi minimal 10 karakter.'
                            : null,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Harga Mulai',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: _decoration('0').copyWith(prefixText: 'Rp '),
                    validator: (String? value) {
                      final num price = num.tryParse(
                            (value ?? '').replaceAll(RegExp(r'[^0-9]'), ''),
                          ) ??
                          0;
                      if (price < 1000) return 'Harga mulai minimal Rp1.000.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Harga ini hanya referensi awal. Customer tetap dapat membuat budget dan Mitra mengirim penawaran final melalui sistem bidding.',
                    style: TextStyle(
                      color: Color(0xFF766A63),
                      fontSize: 10.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: jobOrangeColor,
                        foregroundColor: const Color(0xFF553600),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        _isEditing ? 'Simpan Perubahan' : 'Publikasikan Jasa',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
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
    );
  }
}
