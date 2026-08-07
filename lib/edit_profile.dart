import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/home_shortcut_button.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> userRow; // 👈 Menambahkan parameter userRow

  const EditProfilePage({super.key, required this.userRow});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Color Palette
  final Color primaryBrown = const Color(0xFF8B5A2B);
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
    _addressController = TextEditingController(
      text: widget.userRow['alamat'] ?? '',
    );
  }

  @override
  void dispose() {
    _fullnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /* ---------- SIMPAN PERUBAHAN KE SUPABASE ---------- */
  Future<void> _saveProfile() async {
    final newName = _fullnameController.text.trim();
    final newPhone = _phoneController.text.trim();
    final newAddress = _addressController.text.trim();

    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama lengkap tidak boleh kosong')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sesi telah berakhir, silakan login kembali.')),
          );
        }
        return;
      }

      // Update data pada tabel 'users' di Supabase
      final updates = {
        'fullname': newName,
        'phone': newPhone,
        'alamat': newAddress,
      };

      await _supabase.from('users').update(updates).eq('id', user.id);

      // Update metadata user di Supabase Auth
      await _supabase.auth.updateUser(
        UserAttributes(data: {'fullname': newName}),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil diperbarui!')),
        );
        // Kembali ke halaman sebelumnya dengan membawa status 'true' agar data di-refresh
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui profil: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? avatarUrl = widget.userRow['avatar_url'];

    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryBrown),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
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
                    label: 'Nama Lengkap',
                    controller: _fullnameController,
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 16),

                  // Input Email (Read-Only)
                  _buildInputField(
                    label: 'Email',
                    controller: _emailController,
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    readOnly: true, // Email sebaiknya tidak diubah secara bebas
                  ),
                  const SizedBox(height: 16),

                  // Input Nomor HP
                  _buildInputField(
                    label: 'Nomor HP',
                    controller: _phoneController,
                    icon: Icons.smartphone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  // Input Alamat Lengkap
                  _buildInputField(
                    label: 'Alamat Lengkap',
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
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade300,
                image: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? DecorationImage(
                        image: NetworkImage(avatarUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: (avatarUrl == null || avatarUrl.isEmpty)
                  ? Icon(Icons.person, size: 50, color: Colors.grey.shade600)
                  : null,
            ),

            // Badge Kamera Orange
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryOrange,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
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
        Text(
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
            color: readOnly ? Colors.grey.shade600 : Colors.black87,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: readOnly ? Colors.grey.shade200 : fieldBg,
            prefixIcon: Icon(icon, color: Colors.black54, size: 20),
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
                color: primaryBrown.withOpacity(0.5),
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
            child: Text(
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
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
                : const Text(
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
