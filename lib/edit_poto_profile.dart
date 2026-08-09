import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'widgets/ayo_snackbar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/home_shortcut_button.dart';

class EditPhotoProfilePage extends StatefulWidget {
  final Map<String, dynamic> userRow;

  const EditPhotoProfilePage({super.key, required this.userRow});

  @override
  State<EditPhotoProfilePage> createState() => _EditPhotoProfilePageState();
}

class _EditPhotoProfilePageState extends State<EditPhotoProfilePage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = false;
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  String? _currentAvatarUrl;
  bool _isDeleted = false; // Flag untuk menandai jika foto dihapus

  // Color Palette Tema Ayo Suruh
  static const Color _primaryOrange = Color(0xFFF39C12);
  static const Color _brownColor = Color(0xFF8B5A2B);
  static const Color _bgGrey = Color(0xFFFAF6F3);

  @override
  void initState() {
    super.initState();
    _currentAvatarUrl = widget.userRow['avatar_url'];
  }

  /* ---------- PILIH FOTO (KAMERA / GALERI) ---------- */
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      imageQuality: 70,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedImage = image;
        _imageBytes = bytes;
        _isDeleted = false; // Reset status hapus foto
      });
    }
  }

  /* ---------- HAPUS FOTO PROFIL ---------- */
  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _imageBytes = null;
      _isDeleted = true; // Tandai foto dihapus
    });
  }

  /* ---------- MODAL BOTTOM SHEET (OPSI UBAH FOTO) ---------- */
  void _showPhotoOptionsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- HEADER BOTTOM SHEET ---
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: _brownColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Pilih Foto Profil',
                        style: TextStyle(
                          color: _brownColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- PRATINJAU FOTO PROFIL ---
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _primaryOrange, width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 55,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: !_isDeleted && _imageBytes != null
                              ? MemoryImage(_imageBytes!)
                              : (!_isDeleted &&
                                      _currentAvatarUrl != null &&
                                      _currentAvatarUrl!.isNotEmpty
                                  ? NetworkImage(_currentAvatarUrl!)
                                  : null),
                          child: _isDeleted ||
                                  (_imageBytes == null &&
                                      (_currentAvatarUrl == null ||
                                          _currentAvatarUrl!.isEmpty))
                              ? const Icon(Icons.person, size: 60, color: Colors.grey)
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Pratinjau Foto Profil Anda',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 24),

                  // --- OPTION 1: AMBIL FOTO (KAMERA) ---
                  _buildOptionCard(
                    icon: Icons.camera_alt_outlined,
                    iconBgColor: const Color(0xFFE8F5E9),
                    iconColor: const Color(0xFF4CAF50),
                    title: 'Ambil Foto',
                    subtitle: 'Gunakan kamera ponsel Anda',
                    onTap: () async {
                      await _pickImage(ImageSource.camera);
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 12),

                  // --- OPTION 2: PILIH DARI GALERI ---
                  _buildOptionCard(
                    icon: Icons.photo_library_outlined,
                    iconBgColor: const Color(0xFFE8F5E9),
                    iconColor: const Color(0xFF4CAF50),
                    title: 'Pilih dari Galeri',
                    subtitle: 'Pilih foto terbaik dari penyimpanan',
                    onTap: () async {
                      await _pickImage(ImageSource.gallery);
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 12),

                  // --- OPTION 3: HAPUS FOTO ---
                  _buildOptionCard(
                    icon: Icons.delete_outline,
                    iconBgColor: const Color(0xFFFFEBEE),
                    iconColor: Colors.red,
                    cardBgColor: const Color(0xFFFFF5F5),
                    title: 'Hapus Foto',
                    subtitle: 'Kembali ke foto profil default',
                    titleColor: Colors.red,
                    subtitleColor: Colors.red.shade300,
                    chevronColor: Colors.red.shade300,
                    onTap: () {
                      _removeImage();
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 28),

                  // --- TOMBOL KONFIRMASI / BATAL ---
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryOrange,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'Terapkan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /* ---------- WIDGET HELPER UNTUK KARTU PILIHAN ---------- */
  Widget _buildOptionCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color cardBgColor = const Color(0xFFF8F9FA),
    Color titleColor = Colors.black87,
    Color? subtitleColor,
    Color? chevronColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: subtitleColor ?? Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: chevronColor ?? Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  /* ---------- SIMPAN FOTO PROFIL KE SUPABASE ---------- */
  Future<void> _savePhotoProfile() async {
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

      String? updatedAvatarUrl = _currentAvatarUrl;

      // 1. Logika Hapus Foto vs Upload Foto Baru ke Bucket 'avatars'
      if (_isDeleted) {
        updatedAvatarUrl = null;
      } else if (_selectedImage != null && _imageBytes != null) {
        String fileExt = 'jpg';
        if (_selectedImage!.name.contains('.')) {
          fileExt = _selectedImage!.name.split('.').last.toLowerCase();
        }

        final String contentType = (fileExt == 'jpg' || fileExt == 'jpeg')
            ? 'image/jpeg'
            : 'image/$fileExt';

        final fileName =
            '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        // Upload ke Supabase Storage
        await _supabase.storage.from('avatars').uploadBinary(
              fileName,
              _imageBytes!,
              fileOptions: FileOptions(
                contentType: contentType,
                upsert: true,
              ),
            );

        updatedAvatarUrl =
            _supabase.storage.from('avatars').getPublicUrl(fileName);
      }

      // 2. Update HANYA kolom 'avatar_url' pada tabel 'users'
      await _supabase
          .from('users')
          .update({'avatar_url': updatedAvatarUrl})
          .eq('id', user.id);

      if (mounted) {
        AyoSnackBar.success(context, 'Foto profil berhasil diperbarui.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error updating avatar: $e');
      if (mounted) {
        AyoSnackBar.error(
          context,
          'Gagal memperbarui foto profil: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _brownColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Foto Profil',
          style: TextStyle(
            color: _brownColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,

        actions: const <Widget>[HomeShortcutButton()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Spacer(),

            // --- TAMPILAN UTAMA FOTO PROFIL ---
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 80,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: !_isDeleted && _imageBytes != null
                          ? MemoryImage(_imageBytes!)
                          : (!_isDeleted &&
                                  _currentAvatarUrl != null &&
                                  _currentAvatarUrl!.isNotEmpty
                              ? NetworkImage(_currentAvatarUrl!)
                              : null),
                      child: _isDeleted ||
                              (_imageBytes == null &&
                                  (_currentAvatarUrl == null ||
                                      _currentAvatarUrl!.isEmpty))
                          ? const Icon(Icons.person, size: 80, color: Colors.grey)
                          : null,
                    ),
                  ),

                  // Badge Tombol Edit Kamera
                  GestureDetector(
                    onTap: _showPhotoOptionsSheet,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _primaryOrange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tombol Teks Ubah Foto
            TextButton.icon(
              onPressed: _showPhotoOptionsSheet,
              icon: const Icon(Icons.photo_library_outlined,
                  size: 18, color: _primaryOrange),
              label: const Text(
                'Ubah Foto Profil',
                style: TextStyle(
                  color: _primaryOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),

            const Spacer(),

            // --- TOMBOL SIMPAN FOTO ---
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _savePhotoProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryOrange,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Simpan Foto Profil',
                        style: TextStyle(
                          color: Colors.white,
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
}
