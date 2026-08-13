import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/ayo_snackbar.dart';
import 'widgets/ayo_avatar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/home_shortcut_button.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';
import './theme/ayo_theme.dart';
import 'phone/phone_confirmation_service.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> userRow; // 👈 Menambahkan parameter userRow

  const EditProfilePage({super.key, required this.userRow});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Color Palette
  Color get primaryBrown => AyoAdaptiveColors.brown;
  final Color primaryOrange = const Color(0xFFFA9D18);
  final Color bgGrey = const Color(0xFFFAF7F7);
  final Color fieldBg = const Color(0xFFF7F2F4);
  final Color infoBg = const Color(0xFFF2F5EE);

  // Controller Form
  late TextEditingController _fullnameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  bool _isLoading = false;
  bool _isRequestingPhoneHint = false;
  bool _internalPhoneChange = false;
  late String _phoneVerificationLevel;
  String? _confirmedPhone;

  @override
  void initState() {
    super.initState();
    // Inisialisasi Data dari widget.userRow
    _fullnameController = TextEditingController(
      text: widget.userRow['fullname'] ?? '',
    );
    _emailController = TextEditingController(
      text: widget.userRow['email'] ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.userRow['phone'] ?? '',
    );
    _phoneVerificationLevel =
        (widget.userRow['phone_verification_level'] ??
                PhoneConfirmationService.unverified)
            .toString();
    _confirmedPhone = PhoneConfirmationService.isConfirmed(
      _phoneVerificationLevel,
    )
        ? PhoneConfirmationService.normalizeIndonesiaPhone(
            _phoneController.text,
          )
        : null;
    _phoneController.addListener(_handlePhoneEdited);
    _addressController = TextEditingController(
      text: widget.userRow['alamat'] ?? '',
    );
  }

  @override
  void dispose() {
    _fullnameController.dispose();
    _emailController.dispose();
    _phoneController.removeListener(_handlePhoneEdited);
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _handlePhoneEdited() {
    if (_internalPhoneChange || !mounted) return;
    final String normalized = PhoneConfirmationService.normalizeIndonesiaPhone(
      _phoneController.text,
    );
    if (_confirmedPhone != null && normalized == _confirmedPhone) return;
    if (_phoneVerificationLevel == PhoneConfirmationService.unverified) return;
    setState(() => _phoneVerificationLevel = PhoneConfirmationService.unverified);
  }

  Future<void> _pickPhoneFromDevice() async {
    if (_isRequestingPhoneHint || !PhoneConfirmationService.supportsDeviceHint) {
      return;
    }
    setState(() => _isRequestingPhoneHint = true);
    try {
      final String? phone =
          await PhoneConfirmationService.requestPhoneNumberHint();
      if (!mounted) return;
      if (phone == null) {
        AyoSnackBar.info(context, 'Pemilihan nomor dari perangkat dibatalkan.');
        return;
      }
      if (!PhoneConfirmationService.isValidIndonesiaPhone(phone)) {
        AyoSnackBar.error(
          context,
          'Nomor dari perangkat belum sesuai format nomor Indonesia.',
        );
        return;
      }
      _internalPhoneChange = true;
      _phoneController.text = phone;
      _internalPhoneChange = false;
      setState(() {
        _phoneVerificationLevel = PhoneConfirmationService.deviceConfirmed;
        _confirmedPhone = phone;
      });
      AyoSnackBar.success(context, 'Nomor dari perangkat berhasil dipilih.');
    } on PlatformException {
      if (!mounted) return;
      AyoSnackBar.info(
        context,
        'Nomor SIM belum dapat dibaca otomatis. Masukkan nomor secara manual.',
      );
    } finally {
      if (mounted) setState(() => _isRequestingPhoneHint = false);
    }
  }

  /* ---------- SIMPAN PERUBAHAN KE SUPABASE ---------- */
  Future<void> _saveProfile() async {
    final newName = _fullnameController.text.trim();
    final newPhone = PhoneConfirmationService.normalizeIndonesiaPhone(
      _phoneController.text,
    );
    final newAddress = _addressController.text.trim();

    if (newName.isEmpty) {
      AyoSnackBar.error(context, 'Nama lengkap tidak boleh kosong.');
      return;
    }
    if (!PhoneConfirmationService.isValidIndonesiaPhone(newPhone)) {
      AyoSnackBar.error(context, 'Masukkan nomor HP Indonesia yang valid.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          AyoSnackBar.error(
            context,
            'Sesi telah berakhir, silakan login kembali.',
          );
        }
        return;
      }

      // Update data pada tabel 'users' di Supabase
      final updates = {
        'fullname': newName,
        'alamat': newAddress,
      };

      await _supabase.from('users').update(updates).eq('id', user.id);
      await PhoneConfirmationService.saveCurrentUserPhone(
        phone: newPhone,
        verificationLevel: _phoneVerificationLevel,
      );

      // Update metadata nama user di Supabase Auth. Metadata nomor dan status
      // konfirmasinya disinkronkan oleh PhoneConfirmationService.
      final Map<String, dynamic> metadata = Map<String, dynamic>.from(
        _supabase.auth.currentUser?.userMetadata ?? const <String, dynamic>{},
      );
      metadata['fullname'] = newName;
      metadata['full_name'] = newName;
      await _supabase.auth.updateUser(UserAttributes(data: metadata));

      if (mounted) {
        AyoSnackBar.success(context, 'Profil berhasil diperbarui.');
        // Kembali ke halaman sebelumnya dengan membawa status 'true' agar data di-refresh
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      if (mounted) {
        AyoSnackBar.error(context, 'Gagal memperbarui profil: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? avatarUrl = widget.userRow['avatar_url'];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryBrown),
          onPressed: () => Navigator.pop(context),
        ),
        title: AyoText(
          'Edit Profil',
          style: TextStyle(
            color: primaryBrown,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        titleSpacing: 0,

        actions: const <Widget>[HomeShortcutButton()],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Section Foto Profil
                  _buildProfileAvatar(avatarUrl),
                  const SizedBox(height: 24),

                  // Input Nama Lengkap
                  _buildInputField(
                    label: AyoI18n.t('Nama Lengkap'),
                    controller: _fullnameController,
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 16),

                  // Input Email (Read-Only)
                  _buildInputField(
                    label: AyoI18n.t('Email'),
                    controller: _emailController,
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    readOnly: true, // Email sebaiknya tidak diubah secara bebas
                  ),
                  const SizedBox(height: 16),

                  // Input Nomor HP + konfirmasi perangkat
                  _buildInputField(
                    label: AyoI18n.t('Nomor HP'),
                    controller: _phoneController,
                    icon: Icons.smartphone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 9),
                  if (PhoneConfirmationService.supportsDeviceHint)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isRequestingPhoneHint
                            ? null
                            : _pickPhoneFromDevice,
                        icon: _isRequestingPhoneHint
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sim_card_outlined),
                        label: const AyoText(
                          'Gunakan nomor dari perangkat ini',
                        ),
                      ),
                    ),
                  const SizedBox(height: 7),
                  Row(
                    children: <Widget>[
                      Icon(
                        PhoneConfirmationService.isConfirmed(
                              _phoneVerificationLevel,
                            )
                            ? Icons.verified_user_outlined
                            : Icons.info_outline_rounded,
                        size: 16,
                        color: PhoneConfirmationService.isConfirmed(
                              _phoneVerificationLevel,
                            )
                            ? const Color(0xFF5F784F)
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: AyoText(
                          PhoneConfirmationService.isConfirmed(
                                _phoneVerificationLevel,
                              )
                              ? 'Nomor dikonfirmasi dari perangkat'
                              : 'Nomor manual akan ditandai belum dikonfirmasi',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Input Alamat Lengkap
                  _buildInputField(
                    label: AyoI18n.t('Alamat Lengkap'),
                    controller: _addressController,
                    icon: Icons.location_on_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),

                  // Info Box Catatan
                  _buildInfoBanner(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Tombol Bottom "Simpan Perubahan"
          _buildSaveButton(),
        ],
      ),
    );
  }

  // Widget Avatar & Ubah Foto Profil
  Widget _buildProfileAvatar(String? avatarUrl) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            // Lingkaran Foto Profil
            AyoAvatar(
              imageUrl: avatarUrl,
              size: 100,
              backgroundColor: const Color(0xFFFFEFE1),
              logoPadding: 14,
            ),

            // Badge Kamera Orange
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryOrange,
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Helper Widget Input Field Custom
  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AyoText(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          readOnly: readOnly,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: readOnly ? Colors.grey.shade600 : Theme.of(context).colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: readOnly ? Colors.grey.shade200 : fieldBg,
            prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: primaryBrown.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Widget Banner Informasi
  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: infoBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_rounded,
            color: Colors.grey.shade700,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AyoText(
              'Informasi ini digunakan untuk memudahkan mitra kami dalam proses penjemputan dan pengantaran pesanan Anda.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget Bottom Fixed Save Button
  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryOrange,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            icon: _isLoading
                ? const SizedBox.shrink()
                : const Icon(
                    Icons.save_outlined,
                    color: Color(0xFF4A2B00),
                    size: 20,
                  ),
            label: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Color(0xFF4A2B00),
                      strokeWidth: 2,
                    ),
                  )
                : const AyoText(
                    'Simpan Perubahan',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A2B00),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
