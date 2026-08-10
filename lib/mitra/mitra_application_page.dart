import 'package:flutter/material.dart';
import '../widgets/ayo_snackbar.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../navbar.dart';
import '../location/location_picker_page.dart';
import '../location/osm_geocoding_service.dart';
import '../syarat_ketentuan.dart';
import 'mitra_application_service.dart';
import 'mitra_contract_page.dart';
import 'selfie_camera_page.dart';
import '../widgets/home_shortcut_button.dart';

const Color _mitraOrange = Color(0xFFF39C12);
const Color _mitraBrown = Color(0xFF8B5A2B);
const Color _mitraBackground = Color(0xFFFCF8FC);
const Color _mitraInput = Color(0xFFF7F2F7);
const Color _mitraGreen = Color(0xFF5C744D);

class MitraApplicationPage extends StatefulWidget {
  const MitraApplicationPage({super.key, this.existingApplication});

  final Map<String, dynamic>? existingApplication;

  @override
  State<MitraApplicationPage> createState() => _MitraApplicationPageState();
}

class _MitraApplicationPageState extends State<MitraApplicationPage> {
  final MitraApplicationService _service = MitraApplicationService();
  final ImagePicker _picker = ImagePicker();
  final OsmGeocodingService _geocodingService = OsmGeocodingService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _fullnameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();

  Uint8List? _ktmBytes;
  Uint8List? _selfieBytes;
  String? _ktmName;
  String? _selfieName;
  bool _selfieCapturedFromFrontCamera = false;
  String? _selectedBank;
  bool _termsAccepted = false;
  bool _contractAccepted = false;
  Map<String, dynamic>? _activeContract;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isResolvingAddress = false;
  LatLng? _selectedPoint;
  String _resolvedAddressText = '';

  static const List<String> _banks = <String>[
    'BCA',
    'BRI',
    'BNI',
    'Mandiri',
    'BSI',
    'Bank Jago',
    'SeaBank',
    'GoPay',
    'OVO',
    'DANA',
    'ShopeePay',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _fullnameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _accountController.dispose();
    _geocodingService.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final List<dynamic> initial = await Future.wait<dynamic>(<Future<dynamic>>[
        _service.fetchMyProfile(),
        widget.existingApplication != null
            ? Future<Map<String, dynamic>?>.value(widget.existingApplication)
            : _service.fetchMyApplication(),
        _service.fetchMitraBaseLocation(),
        _service.fetchActiveContract(),
      ]);
      final Map<String, dynamic> profile =
          initial[0] as Map<String, dynamic>;
      final Map<String, dynamic>? application =
          initial[1] as Map<String, dynamic>?;
      final Map<String, dynamic>? baseLocation =
          initial[2] as Map<String, dynamic>?;
      final Map<String, dynamic>? activeContract =
          initial[3] as Map<String, dynamic>?;
      _activeContract = activeContract;

      _fullnameController.text = (profile['fullname'] ?? '').toString();
      _phoneController.text = _normalizePhone(
        (profile['phone'] ?? '').toString(),
      );
      _addressController.text = (baseLocation?['address'] ??
              application?['address'] ??
              profile['alamat'] ??
              '')
          .toString();
      final double? latitude = double.tryParse(
        baseLocation?['latitude']?.toString() ?? '',
      );
      final double? longitude = double.tryParse(
        baseLocation?['longitude']?.toString() ?? '',
      );
      if (latitude != null && longitude != null) {
        _selectedPoint = LatLng(latitude, longitude);
        _resolvedAddressText = _addressController.text.trim();
      }
      _accountController.text = (application?['account_number'] ?? '')
          .toString();

      final String? savedBank = application?['bank_name']?.toString();
      if (savedBank != null && _banks.contains(savedBank)) {
        _selectedBank = savedBank;
      }
    } catch (error) {
      if (mounted) {
        AyoSnackBar.error(
          context,
          'Data pendaftaran belum dapat dimuat: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _normalizePhone(String value) {
    String phone = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.startsWith('62')) phone = phone.substring(2);
    if (phone.startsWith('0')) phone = phone.substring(1);
    return phone;
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
          RegExp(r'\b(?:no\.?|nomor)\s*[a-z0-9./-]+', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'\b(?:kecamatan|kec\.?)\s+', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'\b(?:kota|kabupaten|kab\.?)\s+', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s+,'), ',')
        .replaceAll(RegExp(r',\s*,+'), ', ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (broader.endsWith(',')) {
      broader = broader.substring(0, broader.length - 1).trim();
    }
    if (broader.isNotEmpty && !broader.toLowerCase().contains('indonesia')) {
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

  Future<bool> _resolveMitraAddress({bool showMessage = true}) async {
    final String query = _addressController.text.trim();
    if (query.length < 8) {
      if (showMessage && mounted) {
        AyoSnackBar.info(
          context,
          'Alamat terlalu singkat untuk dicari.',
        );
      }
      return false;
    }

    if (mounted) setState(() => _isResolvingAddress = true);
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
          AyoSnackBar.info(
            context,
            'Alamat belum ditemukan. Tambahkan kecamatan/kota atau pilih titik manual.',
          );
        }
        return false;
      }

      if (!mounted) return false;
      setState(() {
        _selectedPoint = best!.point;
        if (!approximate) {
          _addressController.text = best.displayName;
        }
        _resolvedAddressText = _addressController.text.trim();
      });
      if (showMessage) {
        AyoSnackBar.info(
          context,
          approximate
              ? 'Titik perkiraan ditemukan. Periksa pin sebelum mengirim pengajuan.'
              : 'Titik lokasi Mitra berhasil ditemukan.',
        );
      }
      return true;
    } catch (error) {
      if (showMessage && mounted) {
        AyoSnackBar.error(context, 'Pencarian lokasi gagal: $error');
      }
      return false;
    } finally {
      if (mounted) setState(() => _isResolvingAddress = false);
    }
  }

  Future<void> _pickMitraLocationOnMap() async {
    FocusScope.of(context).unfocus();
    final PickedLocation? picked = await Navigator.push<PickedLocation>(
      context,
      MaterialPageRoute<PickedLocation>(
        builder: (_) => LocationPickerPage(
          initialPoint: _selectedPoint,
          addressLabel: _addressController.text.trim(),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedPoint = picked.point;
      if (picked.addressLabel.trim().isNotEmpty) {
        _addressController.text = picked.addressLabel.trim();
      }
      _resolvedAddressText = _addressController.text.trim();
    });
  }

  Future<void> _pickDocument({required bool isKtm}) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Pilih sumber foto',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFF0DD),
                    child: Icon(Icons.camera_alt_outlined, color: _mitraBrown),
                  ),
                  title: const Text('Kamera'),
                  subtitle: const Text('Ambil foto langsung'),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF0F4EB),
                    child: Icon(
                      Icons.photo_library_outlined,
                      color: _mitraGreen,
                    ),
                  ),
                  title: const Text('Galeri'),
                  subtitle: const Text('Pilih foto dari perangkat'),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return;

    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 78,
        maxWidth: 1800,
        maxHeight: 1800,
      );
      if (picked == null) return;

      final Uint8List bytes = await picked.readAsBytes();
      if (bytes.lengthInBytes > 2 * 1024 * 1024) {
        throw ArgumentError(
          'Ukuran foto masih lebih dari 2 MB. Pilih foto lain atau kompres terlebih dahulu.',
        );
      }

      if (!mounted) return;
      setState(() {
        if (isKtm) {
          _ktmBytes = bytes;
          _ktmName = picked.name;
        } else {
          _selfieBytes = bytes;
          _selfieName = picked.name;
        }
      });
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(context, 'Foto belum dapat dipilih: $error');
    }
  }

  Future<void> _pickSelfieFromFrontCamera() async {
    try {
      final SelfieCaptureResult? result =
          await Navigator.of(context).push<SelfieCaptureResult>(
        MaterialPageRoute<SelfieCaptureResult>(
          fullscreenDialog: true,
          builder: (_) => const SelfieCameraPage(),
        ),
      );
      if (result == null || !mounted) return;

      if (result.bytes.lengthInBytes > 2 * 1024 * 1024) {
        throw ArgumentError(
          'Ukuran selfie masih lebih dari 2 MB. Ambil ulang foto dengan pencahayaan yang baik.',
        );
      }

      setState(() {
        _selfieBytes = result.bytes;
        _selfieName = result.name;
        _selfieCapturedFromFrontCamera = true;
      });
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(context, 'Selfie belum dapat diambil: $error');
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final bool valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    if (_selectedPoint == null ||
        _resolvedAddressText != _addressController.text.trim()) {
      final bool resolved = await _resolveMitraAddress(showMessage: false);
      if (!resolved || _selectedPoint == null) {
        if (!mounted) return;
        AyoSnackBar.error(
          context,
          'Lokasi utama Mitra wajib memiliki titik. Cari otomatis atau pilih titik di peta.',
        );
        return;
      }
    }

    if (!mounted) return;

    if (_ktmBytes == null || _selfieBytes == null) {
      AyoSnackBar.error(
        context,
        'Foto KTM dan foto selfie wajib dilengkapi.',
      );
      return;
    }

    if (!_selfieCapturedFromFrontCamera) {
      AyoSnackBar.error(
        context,
        'Selfie wajib diambil langsung menggunakan kamera depan.',
      );
      return;
    }

    if (!_termsAccepted) {
      AyoSnackBar.error(
        context,
        'Setujui Syarat & Ketentuan terlebih dahulu.',
      );
      return;
    }

    final String contractVersion =
        (_activeContract?['version'] ?? '').toString().trim();
    if (contractVersion.isEmpty) {
      AyoSnackBar.error(
        context,
        'Kontrak/MoU Mitra aktif belum tersedia.',
      );
      return;
    }
    if (!_contractAccepted) {
      AyoSnackBar.error(
        context,
        'Baca dan setujui Kontrak/MoU Mitra terlebih dahulu.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final String ktmPath = await _service.uploadDocument(
        bytes: _ktmBytes!,
        originalName: _ktmName ?? 'ktm.jpg',
        documentType: 'ktm',
      );
      final String selfiePath = await _service.uploadDocument(
        bytes: _selfieBytes!,
        originalName: _selfieName ?? 'selfie.jpg',
        documentType: 'selfie',
      );

      await _service.acceptActiveContract(contractVersion);

      final Map<String, dynamic> application = await _service.submitApplication(
        fullname: _fullnameController.text,
        phone: '+62${_phoneController.text}',
        address: _addressController.text,
        latitude: _selectedPoint!.latitude,
        longitude: _selectedPoint!.longitude,
        bankName: _selectedBank!,
        accountNumber: _accountController.text,
        ktmPath: ktmPath,
        selfiePath: selfiePath,
      );

      if (!mounted) return;
      AyoSnackBar.success(context, 'Pengajuan Mitra berhasil dikirim.');

      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              MitraApplicationStatusPage(initialApplication: application),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(
        context,
        'Pengajuan belum berhasil dikirim: $error',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _mitraBackground,
      appBar: AppBar(
        backgroundColor: _mitraBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _mitraBrown),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Daftar Jadi Mitra',
          style: TextStyle(
            color: _mitraBrown,
            fontWeight: FontWeight.bold,
            fontSize: 21,
          ),
        ),

        actions: const <Widget>[HomeShortcutButton()],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _mitraOrange))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 38),
                child: Column(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE5C6),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.stars_outlined,
                            size: 21,
                            color: _mitraBrown,
                          ),
                          SizedBox(width: 7),
                          Text(
                            'Bergabung sebagai Mitra terverifikasi',
                            style: TextStyle(color: _mitraBrown),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Ayo Bantu Sesama!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF242124),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Butuh bantuan? Ayo suruh kami! Jadilah bagian dari\ntim kami yang handal dan terpercaya.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: Color(0xFF66534B),
                      ),
                    ),
                    const SizedBox(height: 26),
                    _sectionCard(
                      icon: Icons.person_outline,
                      iconColor: const Color(0xFF9B5F00),
                      title: 'Informasi Pribadi',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _fieldLabel('Nama Lengkap'),
                          _textField(
                            controller: _fullnameController,
                            hint: 'Sesuai KTP',
                            validator: (String? value) {
                              if ((value ?? '').trim().length < 3) {
                                return 'Nama lengkap wajib diisi.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 17),
                          _fieldLabel('Nomor WhatsApp'),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                height: 58,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                decoration: const BoxDecoration(
                                  color: _mitraInput,
                                  border: Border(
                                    bottom: BorderSide(color: _mitraBrown),
                                  ),
                                ),
                                child: const Text(
                                  '+62',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _textField(
                                  controller: _phoneController,
                                  hint: '81234567890',
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: <TextInputFormatter>[
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(13),
                                  ],
                                  validator: (String? value) {
                                    final String digits = (value ?? '')
                                        .replaceAll(RegExp(r'[^0-9]'), '');
                                    if (digits.length < 9) {
                                      return 'Nomor WhatsApp belum valid.';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 17),
                          _fieldLabel('Lokasi Utama Mitra'),
                          _textField(
                            controller: _addressController,
                            hint: 'Jl. Raya No. 123, Kelurahan, Kecamatan...',
                            maxLines: 4,
                            onChanged: (String value) {
                              if (_resolvedAddressText.isNotEmpty &&
                                  value.trim() != _resolvedAddressText) {
                                setState(() => _selectedPoint = null);
                              }
                            },
                            validator: (String? value) {
                              if ((value ?? '').trim().length < 10) {
                                return 'Alamat lengkap wajib diisi.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isResolvingAddress
                                      ? null
                                      : _resolveMitraAddress,
                                  icon: _isResolvingAddress
                                      ? const SizedBox(
                                          width: 17,
                                          height: 17,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: _mitraBrown,
                                          ),
                                        )
                                      : const Icon(Icons.auto_fix_high_rounded),
                                  label: const Text('Tentukan Otomatis'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _mitraBrown,
                                    side: const BorderSide(color: _mitraOrange),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  onPressed: _pickMitraLocationOnMap,
                                  icon: const Icon(Icons.map_outlined),
                                  label: const Text('Pilih di Peta'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFEBD0),
                                    foregroundColor: _mitraBrown,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _selectedPoint == null
                                  ? const Color(0xFFFFF4E5)
                                  : const Color(0xFFF0F6EC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Icon(
                                  _selectedPoint == null
                                      ? Icons.location_off_outlined
                                      : Icons.location_on_rounded,
                                  color: _selectedPoint == null
                                      ? _mitraBrown
                                      : _mitraGreen,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    _selectedPoint == null
                                        ? 'Titik lokasi wajib ditentukan agar Customer dapat melihat jarak Mitra dari lokasi pekerjaan.'
                                        : 'Titik Lokasi Utama Mitra sudah siap. Lokasi ini dapat diubah kembali dari Profil Mitra.',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      height: 1.4,
                                      color: Color(0xFF66534B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _sectionCard(
                      icon: Icons.description_outlined,
                      iconColor: _mitraGreen,
                      title: 'Unggah Dokumen',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Foto KTM',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _uploadBox(
                            bytes: _ktmBytes,
                            title: 'Klik untuk unggah',
                            subtitle: 'Format JPG, PNG (Maks 2MB)',
                            icon: Icons.cloud_upload_outlined,
                            onTap: () => _pickDocument(isKtm: true),
                          ),
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 10, 0, 0),
                            child: Text(
                              'Pastikan data terbaca jelas\nBukan hasil scan atau fotokopi berwarna',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.65,
                                color: Color(0xFF66534B),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'Selfie Verifikasi',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Wajib diambil langsung dengan kamera depan. Foto dari galeri tidak dapat digunakan.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color: Color(0xFF66534B),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _uploadBox(
                            bytes: _selfieBytes,
                            title: _selfieBytes == null
                                ? 'Ambil Selfie Sekarang'
                                : 'Ambil Ulang Selfie',
                            subtitle: _selfieBytes == null
                                ? 'Kamera depan akan dibuka'
                                : 'Selfie kamera depan sudah siap',
                            icon: Icons.camera_front_outlined,
                            onTap: _pickSelfieFromFrontCamera,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _sectionCard(
                      icon: Icons.account_balance_wallet_outlined,
                      iconColor: _mitraOrange,
                      title: 'Pencairan Dana',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _fieldLabel('Nama Bank'),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedBank,
                            isExpanded: true,
                            decoration: _inputDecoration('Pilih Bank'),
                            items: _banks
                                .map(
                                  (String bank) => DropdownMenuItem<String>(
                                    value: bank,
                                    child: Text(bank),
                                  ),
                                )
                                .toList(),
                            onChanged: (String? value) {
                              setState(() => _selectedBank = value);
                            },
                            validator: (String? value) => value == null
                                ? 'Pilih bank atau e-wallet.'
                                : null,
                          ),
                          const SizedBox(height: 17),
                          _fieldLabel('Nomor Rekening / E-Wallet'),
                          _textField(
                            controller: _accountController,
                            hint: 'Contoh: 1234567890',
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(24),
                            ],
                            validator: (String? value) {
                              if ((value ?? '').trim().length < 6) {
                                return 'Nomor rekening belum valid.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '*Pastikan nama pemilik rekening sama dengan nama pendaftar',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF66534B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _sectionCard(
                      icon: Icons.handshake_outlined,
                      iconColor: _mitraBrown,
                      title: 'Kontrak / MoU Mitra',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _activeContract == null
                                ? 'Kontrak aktif belum dapat dimuat.'
                                : 'Versi ${_activeContract?['version'] ?? '-'} · ${_activeContract?['title'] ?? 'Kontrak Kemitraan Ayo Suruh'}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _mitraBrown,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Baca isi kontrak sebelum mengirim pengajuan. Persetujuan akan dicatat bersama versi kontrak dan waktu persetujuan.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color: Color(0xFF66534B),
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _activeContract == null
                                ? null
                                : () => Navigator.push<void>(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) => MitraContractPage(
                                          contract: _activeContract!,
                                        ),
                                      ),
                                    ),
                            icon: const Icon(Icons.description_outlined),
                            label: const Text('Baca Kontrak Lengkap'),
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: _contractAccepted,
                            activeColor: _mitraOrange,
                            title: Text(
                              'Saya telah membaca dan menyetujui Kontrak/MoU Mitra versi ${_activeContract?['version'] ?? '-'}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                            onChanged: _activeContract == null
                                ? null
                                : (bool? value) {
                                    setState(() {
                                      _contractAccepted = value ?? false;
                                    });
                                  },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Checkbox(
                          value: _termsAccepted,
                          activeColor: _mitraOrange,
                          onChanged: (bool? value) {
                            setState(() => _termsAccepted = value ?? false);
                          },
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Wrap(
                              children: <Widget>[
                                const Text(
                                  'Saya menyetujui ',
                                  style: TextStyle(
                                    color: Color(0xFF66534B),
                                    height: 1.45,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.push<void>(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const SyaratKetentuanPage(),
                                    ),
                                  ),
                                  child: const Text(
                                    'Syarat & Ketentuan',
                                    style: TextStyle(
                                      color: _mitraBrown,
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Text(
                                  ' menjadi mitra Ayo Suruh dan bersedia menjaga kualitas layanan.',
                                  style: TextStyle(
                                    color: Color(0xFF66534B),
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _mitraOrange,
                          foregroundColor: const Color(0xFF4C3608),
                          disabledBackgroundColor: _mitraOrange.withValues(
                            alpha: 0.55,
                          ),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_outlined),
                        label: Text(
                          _isSubmitting ? 'Mengirim...' : 'Kirim Pendaftaran',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Proses verifikasi membutuhkan waktu 1–3 hari kerja.',
                      style: TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1EAE6)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: Colors.white, size: 21),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF282426),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: const TextStyle(
          color: _mitraBrown,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF818898)),
      filled: true,
      fillColor: _mitraInput,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: _mitraOrange),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      decoration: _inputDecoration(hint),
    );
  }

  Widget _uploadBox({
    required Uint8List? bytes,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: double.infinity,
        height: 172,
        decoration: BoxDecoration(
          color: _mitraInput,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFE4C3A7), width: 1.5),
        ),
        child: bytes != null
            ? Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 19,
                          color: _mitraBrown,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(icon, size: 42, color: _mitraBrown),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5B463B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                ],
              ),
      ),
    );
  }
}

class MitraApplicationStatusPage extends StatefulWidget {
  const MitraApplicationStatusPage({super.key, this.initialApplication});

  final Map<String, dynamic>? initialApplication;

  @override
  State<MitraApplicationStatusPage> createState() =>
      _MitraApplicationStatusPageState();
}

class _MitraApplicationStatusPageState
    extends State<MitraApplicationStatusPage> {
  final MitraApplicationService _service = MitraApplicationService();

  Map<String, dynamic>? _application;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _application = widget.initialApplication;
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic>? latest = await _service.fetchMyApplication();
      if (mounted) setState(() => _application = latest);
    } catch (error) {
      if (mounted) {
        AyoSnackBar.error(
          context,
          'Status belum dapat diperbarui: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String status = (_application?['status'] ?? 'applied')
        .toString()
        .toLowerCase();
    final bool approved = status == 'approved';
    final bool rejected = status == 'rejected';

    final Color statusColor = approved
        ? _mitraGreen
        : rejected
        ? Colors.red.shade700
        : _mitraOrange;
    final IconData statusIcon = approved
        ? Icons.verified_rounded
        : rejected
        ? Icons.cancel_outlined
        : Icons.hourglass_top_rounded;
    final String title = approved
        ? 'Pengajuan Disetujui!'
        : rejected
        ? 'Pengajuan Perlu Diperbaiki'
        : 'Pengajuan Sedang Diverifikasi';
    final String description = approved
        ? 'Selamat! Akunmu sudah aktif sebagai Mitra Ayo Suruh.'
        : rejected
        ? 'Periksa catatan verifikasi, lalu kirim kembali data yang sudah diperbaiki.'
        : 'Tim kami sedang memeriksa identitas dan dokumenmu. Proses biasanya membutuhkan waktu 1–3 hari kerja.';

    return Scaffold(
      backgroundColor: _mitraBackground,
      appBar: AppBar(
        backgroundColor: _mitraBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _mitraBrown),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: const Text(
          'Status Pendaftaran Mitra',
          style: TextStyle(
            color: _mitraBrown,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: <Widget>[
          const HomeShortcutButton(),
          IconButton(
            tooltip: 'Perbarui status',
            onPressed: _isLoading ? null : _refresh,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _mitraBrown,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: _mitraBrown),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Column(
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 30, 22, 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFF0E8E2)),
              ),
              child: Column(
                children: <Widget>[
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.13),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, size: 48, color: statusColor),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF282426),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: Color(0xFF66534B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _detailsCard(status),
            if (rejected &&
                (_application?['review_notes'] ?? '')
                    .toString()
                    .trim()
                    .isNotEmpty) ...<Widget>[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEAEA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFC8C8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Row(
                      children: <Widget>[
                        Icon(Icons.info_outline, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Catatan Verifikasi',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _application!['review_notes'].toString(),
                      style: const TextStyle(height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: approved
                    ? _openMitraDashboard
                    : rejected
                    ? _reapply
                    : _refresh,
                style: ElevatedButton.styleFrom(
                  backgroundColor: approved
                      ? _mitraGreen
                      : rejected
                      ? _mitraOrange
                      : _mitraBrown,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                icon: Icon(
                  approved
                      ? Icons.dashboard_outlined
                      : rejected
                      ? Icons.edit_note_rounded
                      : Icons.refresh_rounded,
                ),
                label: Text(
                  approved
                      ? 'Masuk Dashboard Mitra'
                      : rejected
                      ? 'Perbaiki dan Ajukan Ulang'
                      : 'Periksa Status Terbaru',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailsCard(String status) {
    final DateTime? submittedAt = DateTime.tryParse(
      (_application?['created_at'] ?? '').toString(),
    )?.toLocal();
    final String submittedText = submittedAt == null
        ? '-'
        : DateFormat('dd MMM yyyy, HH:mm').format(submittedAt);

    String statusText = 'Menunggu Verifikasi';
    if (status == 'approved') statusText = 'Disetujui';
    if (status == 'rejected') statusText = 'Perlu Diperbaiki';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E8E2)),
      ),
      child: Column(
        children: <Widget>[
          _detailRow('Status', statusText),
          const Divider(height: 26),
          _detailRow('Tanggal Pengajuan', submittedText),
          const Divider(height: 26),
          _detailRow(
            'Pencairan Dana',
            '${_application?['bank_name'] ?? '-'} • ${_maskedAccount()}',
          ),
          const Divider(height: 26),
          _detailRow(
            'Dokumen',
            _application?['ktm'] != null && _application?['selfie'] != null
                ? 'KTM dan selfie terunggah'
                : 'Belum lengkap',
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  String _maskedAccount() {
    final String value = (_application?['account_number'] ?? '').toString();
    if (value.length <= 4) return value.isEmpty ? '-' : value;
    return '•••• ${value.substring(value.length - 4)}';
  }

  Future<void> _reapply() async {
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => MitraApplicationPage(existingApplication: _application),
      ),
    );
  }

  void _openMitraDashboard() {
    Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(
        builder: (_) => const MainNavigation(initialRole: 'mitra'),
      ),
      (Route<dynamic> route) => false,
    );
  }
}
