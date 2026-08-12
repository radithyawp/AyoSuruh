import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../location/job_location_map.dart';
import '../location/location_picker_page.dart';
import '../location/osm_geocoding_service.dart';
import 'job_helpers.dart';
import 'job_service.dart';
import '../widgets/home_shortcut_button.dart';
import '../widgets/ayo_snackbar.dart';
import '../widgets/rupiah_input_formatter.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';
import '../theme/ayo_theme.dart';

class CreateJobPage extends StatefulWidget {
  const CreateJobPage({
    super.key,
    this.initialCategoryName,
    this.initialTitle,
    this.initialDescription,
    this.initialBudget,
    this.preferredMitraId,
    this.preferredMitraName,
  });

  final String? initialCategoryName;
  final String? initialTitle;
  final String? initialDescription;
  final num? initialBudget;
  final String? preferredMitraId;
  final String? preferredMitraName;

  @override
  State<CreateJobPage> createState() => _CreateJobPageState();
}

class _CreateJobPageState extends State<CreateJobPage> {
  static const int _maxJobBudget = 10000000;
  final JobService _jobService = JobService();
  final OsmGeocodingService _geocodingService = OsmGeocodingService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _destinationAddressController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  final List<XFile> _jobImages = <XFile>[];

  bool _isLoading = true;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _categories = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _addresses = <Map<String, dynamic>>[];
  String? _selectedCategoryId;
  String _selectedWorkMode = jobWorkModeOnsite;
  String? _selectedAddressId;
  String? _selectedDestinationAddressId;
  bool _useNewAddress = false;
  bool _useNewDestinationAddress = true;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  LatLng? _selectedPoint;
  LatLng? _destinationPoint;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.initialTitle?.trim() ?? '';
    _descriptionController.text = widget.initialDescription?.trim() ?? '';
    final num? initialBudget = widget.initialBudget;
    if (initialBudget != null && initialBudget > 0) {
      _budgetController.text = RupiahInputFormatter.format(initialBudget.round());
    }
    _loadInitialData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _destinationAddressController.dispose();
    _budgetController.dispose();
    _geocodingService.dispose();
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
          final String initialName = (widget.initialCategoryName ?? '').trim().toLowerCase();
          Map<String, dynamic>? initialCategory;
          if (initialName.isNotEmpty) {
            for (final Map<String, dynamic> category in categories) {
              if ((category['name'] ?? '').toString().trim().toLowerCase() == initialName) {
                initialCategory = category;
                break;
              }
            }
          }
          final Map<String, dynamic> selectedCategory =
              initialCategory ?? categories.first;
          _selectedCategoryId = selectedCategory['id'].toString();
          _selectedWorkMode = defaultJobWorkModeForCategory(
            (selectedCategory['name'] ?? 'Lainnya').toString(),
          );
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

  Map<String, dynamic>? _selectedAddress({bool destination = false}) {
    final String? addressId = destination
        ? _selectedDestinationAddressId
        : _selectedAddressId;
    if (addressId == null) return null;
    for (final Map<String, dynamic> address in _addresses) {
      if (address['id'].toString() == addressId) return address;
    }
    return null;
  }

  String _currentAddressLabel({bool destination = false}) {
    final bool useNew = destination
        ? _useNewDestinationAddress
        : _useNewAddress;
    final TextEditingController controller = destination
        ? _destinationAddressController
        : _addressController;
    if (useNew || _addresses.isEmpty) {
      final String value = controller.text.trim();
      if (value.isNotEmpty) return value;
      return destination ? 'Alamat tujuan baru' : 'Alamat pekerjaan baru';
    }
    return (_selectedAddress(destination: destination)?['address'] ??
            (destination ? 'Lokasi tujuan' : 'Lokasi pekerjaan'))
        .toString();
  }

  String _selectedCategoryName() {
    final String? selectedId = _selectedCategoryId;
    if (selectedId == null) return 'Lainnya';
    for (final Map<String, dynamic> category in _categories) {
      if (category['id'].toString() == selectedId) {
        return (category['name'] ?? 'Lainnya').toString();
      }
    }
    return 'Lainnya';
  }

  bool get _requiresPhysicalLocation =>
      _selectedWorkMode != jobWorkModeRemote;

  bool get _requiresRouteDestination =>
      workModeNeedsRouteEndpoints(_selectedWorkMode);

  String _workModeRecommendation() {
    final String recommended =
        defaultJobWorkModeForCategory(_selectedCategoryName());
    if (recommended == _selectedWorkMode) {
      return 'Direkomendasikan untuk kategori ${_selectedCategoryName()}.';
    }
    return 'Mode ini kamu pilih manual. Rekomendasi kategori: '
        '${jobWorkModeLabel(recommended)}.';
  }

  String _titleHintForCategory() {
    switch (_selectedCategoryName().trim().toLowerCase()) {
      case 'elektronik':
        return 'Contoh: Perbaiki laptop rusak';
      case 'antar-jemput':
        return 'Contoh: Antar ke stasiun';
      case 'jasa titip':
        return 'Contoh: Titip beli kebutuhan';
      case 'survey & informasi kost':
        return 'Contoh: Survey kost dekat kampus';
      case 'administrasi':
        return 'Contoh: Bantu urus berkas';
      case 'design & coding':
        return 'Contoh: Buat desain poster acara';
      case 'rumah tangga':
        return 'Contoh: Bersihkan kamar kos';
      case 'otomotif':
        return 'Contoh: Bantu ganti aki motor';
      case 'kurir':
        return 'Contoh: Antar paket ke alamat tujuan';
      case 'tukang':
        return 'Contoh: Pasang rak dinding';
      case 'gaya hidup':
        return 'Contoh: Konsultasi, pijat, atau layanan relaksasi';
      default:
        return 'Contoh: Bantuan yang dibutuhkan';
    }
  }

  List<String> _geocodingQueryCandidates(String rawAddress) {
    final String normalized = rawAddress
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s*,\s*'), ', ')
        .trim();
    final List<String> queries = <String>[normalized];

    String broader = normalized
        .replaceAll(
          RegExp(
            r'\b(?:blok|block)\s*[a-z0-9/-]+(?:\s*(?:no\.?|nomor)\s*[a-z0-9./-]+)?',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\b(?:no\.?|nomor)\s*[a-z0-9./-]+',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(r'\b(?:kecamatan|kec\.?)\s+', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(
            r'\b(?:kota|kabupaten|kab\.?)\s+',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+,'), ',')
        .replaceAll(RegExp(r',\s*,+'), ', ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (broader.endsWith(',')) {
      broader = broader.substring(0, broader.length - 1).trim();
    }
    if (broader.isNotEmpty &&
        !broader.toLowerCase().contains('indonesia')) {
      broader = '$broader, Jawa Barat, Indonesia';
    }
    if (broader.isNotEmpty && !queries.contains(broader)) {
      queries.add(broader);
    }

    final List<String> parts = broader
        .split(',')
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList();
    if (parts.length >= 4) {
      final String areaFallback = parts.sublist(parts.length - 4).join(', ');
      if (!queries.contains(areaFallback)) queries.add(areaFallback);
    }

    return queries;
  }

  Future<bool> _resolveTypedAddress({
    bool showMessage = true,
    bool destination = false,
  }) async {
    final TextEditingController controller = destination
        ? _destinationAddressController
        : _addressController;
    final String query = controller.text.trim();
    if (query.length < 8) {
      if (showMessage && mounted) {
        _showMessage('Alamat terlalu singkat untuk dicari.', isError: true);
      }
      return false;
    }

    try {
      final List<String> candidates = _geocodingQueryCandidates(query);
      OsmGeocodingResult? best;
      bool approximate = false;

      for (int index = 0; index < candidates.length; index++) {
        final List<OsmGeocodingResult> results =
            await _geocodingService.search(candidates[index]);
        if (results.isNotEmpty) {
          best = results.first;
          approximate = index > 0;
          break;
        }
      }

      if (best == null) {
        if (showMessage && mounted) {
          _showMessage(
            'Alamat belum ditemukan di OpenStreetMap. Coba format: nama jalan/perumahan, kelurahan, kecamatan, kota; atau pilih titik manual.',
            isError: true,
          );
        }
        return false;
      }

      if (!mounted) return false;
      setState(() {
        if (destination) {
          _destinationPoint = best!.point;
          if (!approximate) {
            _destinationAddressController.text = best.displayName;
          }
          _useNewDestinationAddress = true;
          _selectedDestinationAddressId = null;
        } else {
          _selectedPoint = best!.point;
          // Untuk fallback area yang lebih luas, pertahankan alamat yang diketik
          // pengguna. Titik hanya menjadi perkiraan dan tetap perlu diverifikasi.
          if (!approximate) {
            _addressController.text = best.displayName;
          }
          _useNewAddress = true;
          _selectedAddressId = null;
        }
      });
      if (showMessage) {
        _showMessage(
          approximate
              ? 'Titik perkiraan ditemukan. Pastikan pin sudah tepat sebelum membuat pekerjaan.'
              : 'Titik lokasi otomatis dipilih dari alamat.',
        );
      }
      return true;
    } catch (error) {
      if (showMessage && mounted) {
        _showMessage('Pencarian titik otomatis gagal: $error', isError: true);
      }
      return false;
    }
  }

  Future<void> _pickLocationOnMap({bool destination = false}) async {
    FocusScope.of(context).unfocus();
    final LatLng? currentPoint = destination ? _destinationPoint : _selectedPoint;
    final PickedLocation? location = await Navigator.push<PickedLocation>(
      context,
      MaterialPageRoute<PickedLocation>(
        builder: (_) => LocationPickerPage(
          initialPoint: currentPoint,
          addressLabel: _currentAddressLabel(destination: destination),
        ),
      ),
    );
    if (location != null && mounted) {
      setState(() {
        final String resolvedAddress = location.addressLabel.trim();
        if (destination) {
          _destinationPoint = location.point;
          if (resolvedAddress.isNotEmpty &&
              resolvedAddress != _currentAddressLabel(destination: true).trim()) {
            _useNewDestinationAddress = true;
            _selectedDestinationAddressId = null;
            _destinationAddressController.text = resolvedAddress;
          }
        } else {
          _selectedPoint = location.point;
          if (resolvedAddress.isNotEmpty &&
              resolvedAddress != _currentAddressLabel().trim()) {
            _useNewAddress = true;
            _selectedAddressId = null;
            _addressController.text = resolvedAddress;
          }
        }
      });
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
    if (_requiresPhysicalLocation) {
      if (!_useNewAddress && _selectedAddressId == null) {
        _showMessage('Pilih alamat pekerjaan.', isError: true);
        return;
      }
      if (_selectedPoint == null && (_useNewAddress || _addresses.isEmpty)) {
        final bool resolved = await _resolveTypedAddress(showMessage: false);
        if (!resolved) {
          _showMessage(
            'Alamat belum memiliki titik lokasi. Cari titik otomatis atau pilih di peta.',
            isError: true,
          );
          return;
        }
      }
      if (_selectedPoint == null) {
        _showMessage(
          'Pilih titik lokasi pekerjaan pada peta terlebih dahulu.',
          isError: true,
        );
        return;
      }

      if (_requiresRouteDestination) {
        if (!_useNewDestinationAddress && _selectedDestinationAddressId == null) {
          _showMessage('Pilih alamat tujuan.', isError: true);
          return;
        }
        if (_destinationPoint == null &&
            (_useNewDestinationAddress || _addresses.isEmpty)) {
          final bool resolved = await _resolveTypedAddress(
            showMessage: false,
            destination: true,
          );
          if (!resolved) {
            _showMessage(
              'Alamat tujuan belum memiliki titik lokasi. Cari titik otomatis atau pilih di peta.',
              isError: true,
            );
            return;
          }
        }
        if (_destinationPoint == null) {
          _showMessage(
            'Pilih titik tujuan pada peta terlebih dahulu.',
            isError: true,
          );
          return;
        }
      }
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
      final String jobId = await _jobService.createJob(
        categoryId: _selectedCategoryId!,
        title: _titleController.text,
        description: _descriptionController.text,
        budget: budget,
        workMode: _selectedWorkMode,
        scheduleDate: _selectedDate!,
        scheduleTime: timeValue,
        addressId: _requiresPhysicalLocation && !_useNewAddress
            ? _selectedAddressId
            : null,
        newAddress: _requiresPhysicalLocation && _useNewAddress
            ? _addressController.text
            : null,
        latitude: _requiresPhysicalLocation ? _selectedPoint?.latitude : null,
        longitude: _requiresPhysicalLocation ? _selectedPoint?.longitude : null,
        destinationAddressId: _requiresRouteDestination &&
                !_useNewDestinationAddress
            ? _selectedDestinationAddressId
            : null,
        newDestinationAddress: _requiresRouteDestination &&
                _useNewDestinationAddress
            ? _destinationAddressController.text
            : null,
        destinationLatitude:
            _requiresRouteDestination ? _destinationPoint?.latitude : null,
        destinationLongitude:
            _requiresRouteDestination ? _destinationPoint?.longitude : null,
        preferredMitraId: widget.preferredMitraId,
      );

      String? photoWarning;
      if (_jobImages.isNotEmpty) {
        try {
          await _jobService.uploadJobImages(jobId: jobId, images: _jobImages);
        } catch (error) {
          photoWarning =
              'Pekerjaan berhasil dibuat, tetapi foto belum seluruhnya terunggah. Kamu tetap dapat melanjutkan pekerjaan ini.';
          debugPrint('Upload foto pekerjaan gagal: $error');
        }
      }

      final bool firstJobPriority =
          await _jobService.fetchFirstJobPriorityStatus(jobId);

      if (!mounted) return;
      final String priorityMessage = firstJobPriority
          ? (AyoI18n.isEnglish
              ? 'Your first job receives AYOS Priority for 12 hours so Partners can discover it sooner.'
              : 'Pekerjaan pertamamu mendapat Prioritas AYOS selama 12 jam agar lebih cepat terlihat oleh Mitra.')
          : '';
      final String baseSuccessMessage = widget.preferredMitraId == null
          ? 'Pekerjaanmu sudah tampil untuk mitra. Penawaran yang masuk dapat dilihat dari halaman Pekerjaan.'
          : 'Permintaan ini ditujukan ke ${widget.preferredMitraName ?? 'mitra pilihanmu'}. Mitra tersebut tetap mengirim penawaran melalui alur pekerjaan Ayo Suruh.';
      final String successMessage = <String>[
        baseSuccessMessage,
        if (priorityMessage.isNotEmpty) priorityMessage,
        ?photoWarning,
      ].join('\n\n');
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            icon: CircleAvatar(
              radius: 30,
              backgroundColor: Color(0xFFD9EDCB),
              child: Icon(Icons.check_rounded, color: jobGreenColor, size: 34),
            ),
            title: const AyoText(
              'Pekerjaan Dipublikasikan',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: AyoText(
              successMessage,
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: <Widget>[
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: FilledButton.styleFrom(backgroundColor: jobOrangeColor),
                child: const AyoText('Lihat Pekerjaan'),
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

  Future<void> _addJobPhoto() async {
    if (_jobImages.length >= 5 || _isSubmitting) return;
    final String? source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const AyoText(
                  'Tambah Foto Pekerjaan',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const AyoText(
                  'Tambahkan kondisi barang/lokasi agar Mitra lebih mudah memahami pekerjaan.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF756960)),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const AyoText('Ambil dari Kamera'),
                  onTap: () => Navigator.pop(sheetContext, 'camera'),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const AyoText('Pilih dari Galeri'),
                  subtitle: const AyoText('Bisa memilih beberapa foto sekaligus.'),
                  onTap: () => Navigator.pop(sheetContext, 'gallery'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || source == null) return;

    try {
      final int remaining = 5 - _jobImages.length;
      if (source == 'camera') {
        final XFile? file = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 82,
          maxWidth: 1600,
          maxHeight: 1600,
        );
        if (file != null && mounted) {
          setState(() => _jobImages.add(file));
        }
        return;
      }

      final List<XFile> files = await _imagePicker.pickMultiImage(
        imageQuality: 82,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (!mounted || files.isEmpty) return;
      final List<XFile> accepted = files.take(remaining).toList();
      setState(() => _jobImages.addAll(accepted));
      if (files.length > remaining) {
        _showMessage('Maksimal 5 foto. Hanya $remaining foto pertama yang ditambahkan.');
      }
    } catch (error) {
      _showMessage('Foto belum dapat dipilih: $error', isError: true);
    }
  }

  Widget _buildJobPhotoPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: AyoText(
                _jobImages.isEmpty
                    ? 'Opsional · maksimal 5 foto'
                    : '${_jobImages.length}/5 foto dipilih',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF756960),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _jobImages.length >= 5 ? null : _addJobPhoto,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: AyoText(_jobImages.isEmpty ? 'Tambah Foto' : 'Tambah'),
            ),
          ],
        ),
        if (_jobImages.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _jobImages.length,
              separatorBuilder: (_, _) => const SizedBox(width: 9),
              itemBuilder: (BuildContext context, int index) {
                final XFile file = _jobImages[index];
                return Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 92,
                        height: 92,
                        child: FutureBuilder<Uint8List>(
                          future: file.readAsBytes(),
                          builder: (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
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
                    Positioned(
                      top: -7,
                      right: -7,
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _isSubmitting
                              ? null
                              : () => setState(() => _jobImages.removeAt(index)),
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: Colors.redAccent,
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
        ],
        const SizedBox(height: 5),
        const AyoText(
          'Tips: foto kerusakan, kondisi barang, ukuran, atau area kerja membantu Mitra memberi penawaran yang lebih tepat.',
          style: TextStyle(fontSize: 10.5, height: 1.4, color: Color(0xFF81736B)),
        ),
      ],
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
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
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: jobBrownColor),
        ),
        title: AyoText(
          'Buat Pekerjaan',
          style: TextStyle(
            color: jobBrownColor,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),

        actions: const <Widget>[HomeShortcutButton()],
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
                    if (widget.preferredMitraId != null) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF3E4),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: const Color(0xFFC9DEC0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(
                              Icons.verified_outlined,
                              color: jobGreenColor,
                              size: 21,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: AyoText(
                                'Permintaan jasa untuk ${widget.preferredMitraName ?? 'Mitra pilihan'}. Job ini akan ditampilkan kepada mitra tersebut dan tetap memakai sistem penawaran Ayo Suruh.',
                                style: const TextStyle(
                                  fontSize: 10.8,
                                  height: 1.4,
                                  color: Color(0xFF526046),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    _sectionLabel('Kategori Layanan'),
                    const SizedBox(height: 8),
                    _buildCategoryPicker(),
                    const SizedBox(height: 18),
                    _sectionLabel('Cara Pengerjaan'),
                    const SizedBox(height: 8),
                    _buildWorkModePicker(),
                    const SizedBox(height: 22),
                    _sectionLabel('Judul Pekerjaan'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _titleController,
                      hintText: _titleHintForCategory(),
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
                      hintText: AyoI18n.t('Jelaskan apa yang perlu dikerjakan secara detail...'),
                      maxLines: 5,
                      validator: (String? value) {
                        if (value == null || value.trim().length < 10) {
                          return 'Deskripsi minimal 10 karakter.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    _sectionLabel('Foto Pekerjaan'),
                    const SizedBox(height: 5),
                    _buildJobPhotoPicker(),
                    const SizedBox(height: 18),
                    if (_requiresPhysicalLocation) ...<Widget>[
                      _sectionLabel(
                        _requiresRouteDestination
                            ? 'Rute Pekerjaan'
                            : 'Lokasi Pekerjaan',
                      ),
                      const SizedBox(height: 6),
                      if (_requiresRouteDestination) ...<Widget>[
                        const AyoText(
                          'Isi titik awal dan tujuan. Customer dapat melihat live location Mitra saat perjalanan berlangsung.',
                          style: TextStyle(
                            fontSize: 10.8,
                            height: 1.4,
                            color: Color(0xFF786B63),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      _buildAddressSection(),
                      if (_requiresRouteDestination) ...<Widget>[
                        const SizedBox(height: 12),
                        _buildAddressSection(destination: true),
                      ],
                      const SizedBox(height: 18),
                    ] else ...<Widget>[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF3E4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFC7DDB8)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(
                              Icons.laptop_mac_rounded,
                              color: jobGreenColor,
                              size: 21,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: AyoText(
                                'Pekerjaan dilakukan secara online. Alamat dan tahap menuju lokasi tidak diperlukan.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.45,
                                  color: Color(0xFF526046),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _dateTimeBox(
                            label: AyoI18n.t('Tanggal'),
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
                            label: AyoI18n.t('Waktu'),
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
                      hintText: AyoI18n.t('0'),
                      prefixText: 'Rp ',
                      keyboardType: TextInputType.number,
                      inputFormatters: const <TextInputFormatter>[
                        RupiahInputFormatter(maxValue: _maxJobBudget),
                      ],
                      validator: (String? value) {
                        final int amount = RupiahInputFormatter.parse(value ?? '');
                        if (amount < 1000) {
                          return 'Estimasi harga minimal Rp1.000.';
                        }
                        if (amount > _maxJobBudget) {
                          return 'Estimasi harga maksimal Rp10.000.000.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    const AyoText(
                      'Minimal Rp1.000 • Maksimal Rp10.000.000. Harga yang wajar membantu Mitra memberikan penawaran yang sesuai.',
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
                            : const AyoText(
                                'Buat Pekerjaan',
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
    return AyoText(
      value,
      style: TextStyle(
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
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: jobBorderColor),
        ),
        child: const AyoText('Belum ada kategori pada database.'),
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
          showCheckmark: false,
          onSelected: (_) => setState(() {
            _selectedCategoryId = id;
            _selectedWorkMode = defaultJobWorkModeForCategory(name);
          }),
          avatar: Icon(
            categoryIcon(name),
            size: 17,
            color: selected ? jobGreenColor : jobDarkBrownColor,
          ),
          label: AyoText(name),
          labelStyle: TextStyle(
            color: selected
                ? jobGreenColor
                : Theme.of(context).colorScheme.onSurface,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
          selectedColor: Theme.of(context).brightness == Brightness.dark
              ? Color.alphaBlend(
                  AyoColors.green.withValues(alpha: 0.18),
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                )
              : const Color(0xFFDDEBD5),
          backgroundColor: Theme.of(context).colorScheme.surface,
          side: BorderSide(
            color: selected ? const Color(0xFFA8C895) : jobBorderColor,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        );
      }).toList(),
    );
  }

  Widget _buildWorkModePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: jobWorkModes.map((String mode) {
            final bool selected = mode == _selectedWorkMode;
            return ChoiceChip(
              selected: selected,
              showCheckmark: false,
              onSelected: (_) => setState(() => _selectedWorkMode = mode),
              avatar: Icon(
                jobWorkModeIcon(mode),
                size: 17,
                color: selected ? jobGreenColor : jobDarkBrownColor,
              ),
              label: AyoText(jobWorkModeLabel(mode)),
              labelStyle: TextStyle(
                color: selected
                ? jobGreenColor
                : Theme.of(context).colorScheme.onSurface,
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              selectedColor: Theme.of(context).brightness == Brightness.dark
              ? Color.alphaBlend(
                  AyoColors.green.withValues(alpha: 0.18),
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                )
              : const Color(0xFFDDEBD5),
              backgroundColor: Theme.of(context).colorScheme.surface,
              side: BorderSide(
                color: selected ? const Color(0xFFA8C895) : jobBorderColor,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 7),
        AyoText(
          '${AyoI18n.t(jobWorkModeDescription(_selectedWorkMode))} '
          '${AyoI18n.t(_workModeRecommendation())}',
          style: TextStyle(
            fontSize: 10.5,
            height: 1.4,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildAddressSection({bool destination = false}) {
    final bool useNew = destination
        ? _useNewDestinationAddress
        : _useNewAddress;
    final String? selectedAddressId = destination
        ? _selectedDestinationAddressId
        : _selectedAddressId;
    final LatLng? selectedPoint = destination
        ? _destinationPoint
        : _selectedPoint;
    final TextEditingController controller = destination
        ? _destinationAddressController
        : _addressController;
    final String endpointLabel = destination
        ? jobDestinationLabelForCategory(_selectedCategoryName())
        : (_requiresRouteDestination
            ? jobOriginLabelForCategory(_selectedCategoryName())
            : 'Lokasi Pekerjaan');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: jobBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: destination
                      ? const Color(0xFFFFF0DE)
                      : const Color(0xFFEAF3E4),
                  shape: BoxShape.circle,
                ),
                child: AyoText(
                  _requiresRouteDestination ? (destination ? 'B' : 'A') : '•',
                  style: TextStyle(
                    color: destination ? jobBrownColor : jobGreenColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: AyoText(
                  endpointLabel,
                  style: TextStyle(
                    color: jobDarkBrownColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_addresses.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFAF7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: jobBorderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: useNew ? '__new__' : selectedAddressId,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  items: <DropdownMenuItem<String>>[
                    ..._addresses.map((Map<String, dynamic> address) {
                      final String label =
                          (address['label'] ?? 'Alamat').toString();
                      final String value = address['address'].toString();
                      return DropdownMenuItem<String>(
                        value: address['id'].toString(),
                        child: AyoText(
                          '$label · $value',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                    const DropdownMenuItem<String>(
                      value: '__new__',
                      child: AyoText('+ Gunakan alamat baru'),
                    ),
                  ],
                  onChanged: (String? value) {
                    setState(() {
                      final bool newValue = value == '__new__';
                      if (destination) {
                        _useNewDestinationAddress = newValue;
                        _selectedDestinationAddressId = newValue ? null : value;
                        _destinationPoint = newValue
                            ? null
                            : _pointFromAddress(
                                _selectedAddress(destination: true),
                              );
                      } else {
                        _useNewAddress = newValue;
                        _selectedAddressId = newValue ? null : value;
                        _selectedPoint = newValue
                            ? null
                            : _pointFromAddress(_selectedAddress());
                      }
                    });
                  },
                ),
              ),
            ),
          if (_addresses.isNotEmpty && useNew) const SizedBox(height: 10),
          if (useNew || _addresses.isEmpty)
            _buildTextField(
              controller: controller,
              hintText: destination
                  ? 'Masukkan alamat tujuan lengkap'
                  : 'Masukkan alamat lengkap',
              prefixIcon: destination
                  ? Icons.flag_outlined
                  : Icons.location_on_outlined,
              maxLines: 3,
              onFieldSubmitted: (_) => _resolveTypedAddress(
                destination: destination,
              ),
              validator: (String? value) {
                if ((useNew || _addresses.isEmpty) &&
                    (value == null || value.trim().length < 8)) {
                  return 'Alamat lengkap minimal 8 karakter.';
                }
                return null;
              },
            ),
          if (useNew || _addresses.isEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () => _resolveTypedAddress(destination: destination),
                icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: const AyoText('Tentukan titik otomatis'),
                style: TextButton.styleFrom(foregroundColor: jobBrownColor),
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (selectedPoint != null) ...<Widget>[
            JobLocationMapCard(
              title: '$endpointLabel Terpilih',
              enableOpenMap: false,
              job: <String, dynamic>{
                'latitude': selectedPoint.latitude,
                'longitude': selectedPoint.longitude,
                'addresses': <String, dynamic>{
                  'address': _currentAddressLabel(destination: destination),
                },
              },
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _pickLocationOnMap(destination: destination),
              icon: Icon(
                selectedPoint == null
                    ? Icons.add_location_alt_outlined
                    : Icons.edit_location_alt_outlined,
              ),
              label: AyoText(
                selectedPoint == null
                    ? 'Pilih Titik di Peta'
                    : 'Ubah Titik Lokasi',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: jobBrownColor,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: AyoText(
                  destination
                      ? 'Pastikan titik tujuan tepat agar Mitra mengantar ke lokasi yang benar.'
                      : (_requiresRouteDestination
                          ? 'Titik A adalah lokasi awal pengambilan atau penjemputan.'
                          : 'Pastikan pin berada di lokasi pekerjaan yang benar agar Mitra tidak tersesat.'),
                  style: const TextStyle(
                    fontSize: 10.8,
                    height: 1.35,
                    color: Color(0xFF786B62),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: jobBorderColor),
            ),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 19, color: jobBrownColor),
                const SizedBox(width: 8),
                Expanded(
                  child: AyoText(
                    value,
                    style: TextStyle(
                      color: value.contains('-') || value.contains('dd')
                          ? Colors.grey.shade500
                          : Theme.of(context).colorScheme.onSurface,
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
    ValueChanged<String>? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: maxLines > 1 ? TextInputAction.newline : textInputAction,
      inputFormatters: inputFormatters,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        hintText: hintText,
        prefixText: prefixText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, color: jobBrownColor),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: jobBorderColor),
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
