import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../location/job_location_map.dart';
import '../location/location_picker_page.dart';
import 'job_helpers.dart';
import 'job_service.dart';

class CreateJobPage extends StatefulWidget {
  const CreateJobPage({super.key});

  @override
  State<CreateJobPage> createState() => _CreateJobPageState();
}

class _CreateJobPageState extends State<CreateJobPage> {
  final JobService _jobService = JobService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _categories = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _addresses = <Map<String, dynamic>>[];
  String? _selectedCategoryId;
  String? _selectedAddressId;
  bool _useNewAddress = false;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  LatLng? _selectedPoint;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
        _jobService.fetchCategories(),
        _jobService.fetchMyAddresses(),
        _jobService.fetchMyProfile(),
      ]);
      final List<Map<String, dynamic>> categories =
          result[0] as List<Map<String, dynamic>>;
      final List<Map<String, dynamic>> addresses =
          result[1] as List<Map<String, dynamic>>;
      final Map<String, dynamic>? profile = result[2] as Map<String, dynamic>?;

      if (!mounted) return;
      setState(() {
        _categories = categories;
        _addresses = addresses;
        if (categories.isNotEmpty) {
          _selectedCategoryId = categories.first['id'].toString();
        }
        if (addresses.isNotEmpty) {
          _selectedAddressId = addresses.first['id'].toString();
          _selectedPoint = _pointFromAddress(addresses.first);
        } else {
          _useNewAddress = true;
          _addressController.text = (profile?['alamat'] ?? '').toString();
        }
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Gagal memuat form pekerjaan: $error', isError: true);
    }
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? value = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      helpText: 'Pilih tanggal pekerjaan',
    );
    if (value != null && mounted) {
      setState(() => _selectedDate = value);
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? value = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Pilih waktu pekerjaan',
    );
    if (value != null && mounted) {
      setState(() => _selectedTime = value);
    }
  }

  LatLng? _pointFromAddress(Map<String, dynamic>? address) {
    if (address == null) return null;
    final double? latitude = address['latitude'] is num
        ? (address['latitude'] as num).toDouble()
        : double.tryParse(address['latitude']?.toString() ?? '');
    final double? longitude = address['longitude'] is num
        ? (address['longitude'] as num).toDouble()
        : double.tryParse(address['longitude']?.toString() ?? '');
    if (latitude == null || longitude == null) return null;
    return LatLng(latitude, longitude);
  }

  Map<String, dynamic>? _selectedAddress() {
    final String? addressId = _selectedAddressId;
    if (addressId == null) return null;
    for (final Map<String, dynamic> address in _addresses) {
      if (address['id'].toString() == addressId) return address;
    }
    return null;
  }

  String _currentAddressLabel() {
    if (_useNewAddress || _addresses.isEmpty) {
      final String value = _addressController.text.trim();
      return value.isEmpty ? 'Alamat pekerjaan baru' : value;
    }
    return (_selectedAddress()?['address'] ?? 'Lokasi pekerjaan').toString();
  }

  Future<void> _pickLocationOnMap() async {
    FocusScope.of(context).unfocus();
    final LatLng? point = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute<LatLng>(
        builder: (_) => LocationPickerPage(
          initialPoint: _selectedPoint,
          addressLabel: _currentAddressLabel(),
        ),
      ),
    );
    if (point != null && mounted) {
      setState(() => _selectedPoint = point);
    }
  }

  Future<void> _publishJob() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      _showMessage('Pilih kategori layanan terlebih dahulu.', isError: true);
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      _showMessage('Tanggal dan waktu pekerjaan wajib dipilih.', isError: true);
      return;
    }
    if (!_useNewAddress && _selectedAddressId == null) {
      _showMessage('Pilih alamat pekerjaan.', isError: true);
      return;
    }
    if (_selectedPoint == null) {
      _showMessage(
        'Pilih titik lokasi pekerjaan pada peta terlebih dahulu.',
        isError: true,
      );
      return;
    }

    final DateTime scheduledAt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    if (!scheduledAt.isAfter(DateTime.now())) {
      _showMessage('Jadwal pekerjaan harus lebih lambat dari waktu sekarang.',
          isError: true);
      return;
    }

    final String digits = _budgetController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final num budget = num.tryParse(digits) ?? 0;

    setState(() => _isSubmitting = true);
    try {
      final String timeValue =
          '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}:00';
      await _jobService.createJob(
        categoryId: _selectedCategoryId!,
        title: _titleController.text,
        description: _descriptionController.text,
        budget: budget,
        scheduleDate: _selectedDate!,
        scheduleTime: timeValue,
        addressId: _useNewAddress ? null : _selectedAddressId,
        newAddress: _useNewAddress ? _addressController.text : null,
        latitude: _selectedPoint!.latitude,
        longitude: _selectedPoint!.longitude,
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            icon: const CircleAvatar(
              radius: 30,
              backgroundColor: Color(0xFFD9EDCB),
              child: Icon(Icons.check_rounded, color: jobGreenColor, size: 34),
            ),
            title: const Text(
              'Pekerjaan Dipublikasikan',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'Pekerjaanmu sudah tampil untuk mitra. Penawaran yang masuk dapat dilihat dari halaman Pekerjaan.',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: <Widget>[
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: FilledButton.styleFrom(backgroundColor: jobOrangeColor),
                child: const Text('Lihat Pekerjaan'),
              ),
            ],
          );
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _showMessage('Pekerjaan belum berhasil dipublikasikan: $error',
          isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : jobGreenColor,
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
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: jobBrownColor),
        ),
        title: const Text(
          'Buat Pekerjaan',
          style: TextStyle(
            color: jobBrownColor,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: jobOrangeColor))
          : SafeArea(
              top: false,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                  children: <Widget>[
                    _sectionLabel('Kategori Layanan'),
                    const SizedBox(height: 8),
                    _buildCategoryPicker(),
                    const SizedBox(height: 22),
                    _sectionLabel('Judul Pekerjaan'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _titleController,
                      hintText: 'Contoh: Bersihkan taman belakang',
                      textInputAction: TextInputAction.next,
                      validator: (String? value) {
                        if (value == null || value.trim().length < 5) {
                          return 'Judul minimal 5 karakter.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    _sectionLabel('Deskripsi Detail Pekerjaan'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _descriptionController,
                      hintText: 'Jelaskan apa yang perlu dikerjakan secara detail...',
                      maxLines: 5,
                      validator: (String? value) {
                        if (value == null || value.trim().length < 10) {
                          return 'Deskripsi minimal 10 karakter.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    _sectionLabel('Lokasi Pekerjaan'),
                    const SizedBox(height: 8),
                    _buildAddressSection(),
                    const SizedBox(height: 18),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _dateTimeBox(
                            label: 'Tanggal',
                            value: _selectedDate == null
                                ? 'dd/mm/yyyy'
                                : '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}',
                            icon: Icons.calendar_month_outlined,
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _dateTimeBox(
                            label: 'Waktu',
                            value: _selectedTime == null
                                ? '--:--'
                                : _selectedTime!.format(context),
                            icon: Icons.access_time_rounded,
                            onTap: _pickTime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _sectionLabel('Estimasi Harga'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _budgetController,
                      hintText: 'Rp 0',
                      prefixText: 'Rp ',
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (String? value) {
                        final num amount =
                            num.tryParse((value ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                        if (amount < 1000) return 'Masukkan estimasi harga yang wajar.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Harga yang wajar membantu mitra memberikan penawaran yang sesuai.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF7C6F67)),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _publishJob,
                        style: FilledButton.styleFrom(
                          backgroundColor: jobOrangeColor,
                          disabledBackgroundColor: const Color(0xFFFFC879),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Publish Pekerjaan',
                                style: TextStyle(
                                  color: Color(0xFF5E3B00),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionLabel(String value) {
    return Text(
      value,
      style: const TextStyle(
        color: jobBrownColor,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildCategoryPicker() {
    if (_categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: jobBorderColor),
        ),
        child: const Text('Belum ada kategori pada database.'),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((Map<String, dynamic> category) {
        final String id = category['id'].toString();
        final String name = (category['name'] ?? 'Lainnya').toString();
        final bool selected = id == _selectedCategoryId;
        return ChoiceChip(
          selected: selected,
          onSelected: (_) => setState(() => _selectedCategoryId = id),
          avatar: Icon(
            categoryIcon(name),
            size: 17,
            color: selected ? jobGreenColor : jobDarkBrownColor,
          ),
          label: Text(name),
          labelStyle: TextStyle(
            color: selected ? jobGreenColor : const Color(0xFF4C4038),
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
          selectedColor: const Color(0xFFDDEBD5),
          backgroundColor: Colors.white,
          side: BorderSide(
            color: selected ? const Color(0xFFA8C895) : jobBorderColor,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        );
      }).toList(),
    );
  }

  Widget _buildAddressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_addresses.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: jobBorderColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _useNewAddress ? '__new__' : _selectedAddressId,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                items: <DropdownMenuItem<String>>[
                  ..._addresses.map((Map<String, dynamic> address) {
                    final String label = (address['label'] ?? 'Alamat').toString();
                    final String value = address['address'].toString();
                    return DropdownMenuItem<String>(
                      value: address['id'].toString(),
                      child: Text(
                        '$label · $value',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                  const DropdownMenuItem<String>(
                    value: '__new__',
                    child: Text('+ Gunakan alamat baru'),
                  ),
                ],
                onChanged: (String? value) {
                  setState(() {
                    _useNewAddress = value == '__new__';
                    _selectedAddressId = _useNewAddress ? null : value;
                    _selectedPoint = _useNewAddress
                        ? null
                        : _pointFromAddress(_selectedAddress());
                  });
                },
              ),
            ),
          ),
        if (_addresses.isNotEmpty && _useNewAddress) const SizedBox(height: 10),
        if (_useNewAddress || _addresses.isEmpty)
          _buildTextField(
            controller: _addressController,
            hintText: 'Masukkan alamat lengkap',
            prefixIcon: Icons.location_on_outlined,
            maxLines: 3,
            validator: (String? value) {
              if ((_useNewAddress || _addresses.isEmpty) &&
                  (value == null || value.trim().length < 8)) {
                return 'Alamat lengkap minimal 8 karakter.';
              }
              return null;
            },
          ),
        const SizedBox(height: 10),
        if (_selectedPoint != null) ...<Widget>[
          JobLocationMapCard(
            title: 'Titik Lokasi Terpilih',
            enableOpenMap: false,
            job: <String, dynamic>{
              'latitude': _selectedPoint!.latitude,
              'longitude': _selectedPoint!.longitude,
              'addresses': <String, dynamic>{
                'address': _currentAddressLabel(),
              },
            },
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _pickLocationOnMap,
            style: OutlinedButton.styleFrom(
              foregroundColor: jobBrownColor,
              side: const BorderSide(color: jobOrangeColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            icon: Icon(
              _selectedPoint == null
                  ? Icons.add_location_alt_outlined
                  : Icons.edit_location_alt_outlined,
            ),
            label: Text(
              _selectedPoint == null
                  ? 'Pilih Titik di Peta'
                  : 'Ubah Titik Lokasi',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.info_outline_rounded, size: 15, color: jobBrownColor),
            SizedBox(width: 5),
            Expanded(
              child: Text(
                'Pastikan pin berada di lokasi pekerjaan yang benar agar mitra tidak tersesat.',
                style: TextStyle(fontSize: 11, color: Color(0xFF786B62)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dateTimeBox({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _sectionLabel(label),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: jobBorderColor),
            ),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 19, color: jobBrownColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: value.contains('-') || value.contains('dd')
                          ? Colors.grey.shade500
                          : Colors.black87,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    String? prefixText,
    IconData? prefixIcon,
    int maxLines = 1,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: maxLines > 1 ? TextInputAction.newline : textInputAction,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        prefixText: prefixText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, color: jobBrownColor),
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
      ),
    );
  }
}
