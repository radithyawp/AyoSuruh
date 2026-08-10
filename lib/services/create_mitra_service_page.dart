import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../jobs/job_helpers.dart';
import '../jobs/job_service.dart';
import 'mitra_service_service.dart';
import '../widgets/home_shortcut_button.dart';
import '../widgets/ayo_snackbar.dart';

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
  final ImagePicker _imagePicker = ImagePicker();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;

  List<Map<String, dynamic>> _categories = <Map<String, dynamic>>[];
  String? _categoryId;
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _existingImages = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _removedImages = <Map<String, dynamic>>[];
  final List<XFile> _newImages = <XFile>[];

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
    final dynamic rawImages = existing?['service_images'];
    if (rawImages is List) {
      _existingImages = rawImages
          .whereType<Map>()
          .map((Map image) => Map<String, dynamic>.from(image))
          .toList();
    }
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
      final List<Map<String, dynamic>> images = _isEditing
          ? await _service.fetchServiceImages(
              widget.existingService!['id'].toString(),
            )
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _categories = categories;
        if (_isEditing) _existingImages = images;
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
    if (_existingImages.length + _newImages.length < 1) {
      _showMessage(
        'Tambahkan minimal 1 foto katalog sebagai cover jasa.',
        error: true,
      );
      return;
    }

    final num price = num.tryParse(
          _priceController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        final String serviceId = widget.existingService!['id'].toString();
        await _service.updateService(
          serviceId: serviceId,
          categoryId: categoryId,
          title: _titleController.text,
          description: _descriptionController.text,
          startingPrice: price,
        );
        for (final Map<String, dynamic> image in _removedImages) {
          await _service.deleteServiceImage(
            serviceId: serviceId,
            imageId: image['id'].toString(),
            storagePath: (image['storage_path'] ?? '').toString(),
          );
        }
        await _service.uploadServiceImages(
          serviceId: serviceId,
          images: _newImages,
          startingOrder: _existingImages.length,
        );
        await _service.normalizeServiceCover(serviceId);
      } else {
        final String serviceId = await _service.createService(
          categoryId: categoryId,
          title: _titleController.text,
          description: _descriptionController.text,
          startingPrice: price,
        );
        try {
          await _service.uploadServiceImages(
            serviceId: serviceId,
            images: _newImages,
          );
        } catch (_) {
          await _service.deleteService(serviceId);
          rethrow;
        }
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      _showMessage('Jasa belum dapat disimpan: $error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addCatalogPhotos() async {
    final int currentCount = _existingImages.length + _newImages.length;
    if (currentCount >= 5 || _saving) return;
    final String? source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const ListTile(
                title: Text(
                  'Tambah Foto Katalog',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text('Foto pertama akan digunakan sebagai cover jasa.'),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Ambil dari Kamera'),
                onTap: () => Navigator.pop(sheetContext, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Pilih dari Galeri'),
                subtitle: const Text('Bisa memilih beberapa foto sekaligus.'),
                onTap: () => Navigator.pop(sheetContext, 'gallery'),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
    if (!mounted || source == null) return;

    try {
      final int remaining = 5 - currentCount;
      if (source == 'camera') {
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 82,
          maxWidth: 1600,
          maxHeight: 1600,
        );
        if (image != null && mounted) {
          setState(() => _newImages.add(image));
        }
        return;
      }

      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: 82,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (!mounted || images.isEmpty) return;
      final List<XFile> accepted = images.take(remaining).toList();
      setState(() => _newImages.addAll(accepted));
      if (images.length > remaining) {
        _showMessage(
          'Maksimal 5 foto katalog. Hanya $remaining foto pertama yang ditambahkan.',
        );
      }
    } catch (error) {
      _showMessage('Foto katalog belum dapat dipilih: $error', error: true);
    }
  }

  Widget _buildCatalogPhotoPicker() {
    final int count = _existingImages.length + _newImages.length;
    final int totalItems = count + (count < 5 ? 1 : 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          count == 0
              ? 'Minimal 1 cover · maksimal 5 foto'
              : '$count/5 foto · foto pertama menjadi cover',
          style: const TextStyle(fontSize: 11, color: Color(0xFF756960)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: totalItems,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (BuildContext context, int index) {
              if (index == count) {
                return InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: _addCatalogPhotos,
                  child: Container(
                    width: 104,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E3),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: jobOrangeColor),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.add_photo_alternate_outlined, color: jobBrownColor),
                        SizedBox(height: 6),
                        Text(
                          'Tambah Foto',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final bool existing = index < _existingImages.length;
              final Map<String, dynamic>? remote =
                  existing ? _existingImages[index] : null;
              final XFile? local = existing
                  ? null
                  : _newImages[index - _existingImages.length];
              return Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: SizedBox(
                      width: 104,
                      height: 110,
                      child: existing
                          ? Image.network(
                              (remote?['image_url'] ?? '').toString(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const ColoredBox(
                                color: Color(0xFFF1ECE8),
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            )
                          : FutureBuilder<Uint8List>(
                              future: local!.readAsBytes(),
                              builder: (
                                BuildContext context,
                                AsyncSnapshot<Uint8List> snapshot,
                              ) {
                                if (!snapshot.hasData) {
                                  return const ColoredBox(
                                    color: Color(0xFFF1ECE8),
                                    child: Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  );
                                }
                                return Image.memory(snapshot.data!, fit: BoxFit.cover);
                              },
                            ),
                    ),
                  ),
                  if (index == 0)
                    Positioned(
                      left: 7,
                      bottom: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          'COVER',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: -7,
                    right: -7,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _saving || count <= 1
                            ? null
                            : () {
                                setState(() {
                                  if (existing) {
                                    final Map<String, dynamic> removed =
                                        _existingImages.removeAt(index);
                                    _removedImages.add(removed);
                                  } else {
                                    _newImages.removeAt(
                                      index - _existingImages.length,
                                    );
                                  }
                                });
                              },
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: count <= 1 ? Colors.grey : Colors.redAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Gunakan foto hasil kerja/portofolio sendiri. Hindari watermark atau data pribadi customer.',
          style: TextStyle(fontSize: 10.5, height: 1.4, color: Color(0xFF81736B)),
        ),
      ],
    );
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    if (error) {
      AyoSnackBar.error(context, message);
    } else {
      AyoSnackBar.success(context, message);
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
      body: SafeArea(
        top: false,
        child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: jobOrangeColor),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
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
                    'Foto Katalog Jasa',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  _buildCatalogPhotoPicker(),
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
