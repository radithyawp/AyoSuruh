import 'package:flutter/material.dart';
import 'package:ayosuruh/login.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Client instance Supabase
  final SupabaseClient _supabase = Supabase.instance.client;

  Map<String, dynamic>? _userRow;
  bool _isLoading = true;

  // Warna-warna utama sesuai desain
  static const Color _primaryColor = Color(0xFFF39C12); // Oranye banner
  static const Color _brownTextColor = Color(0xFF90590F); // Coklat teks/edit
  static const Color _iconBgColor = Color(0xFFF3EEED);

  /* ---------- LIFE-CYCLE ---------- */
  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  /* ---------- MEMUAT DATA USER ---------- */
  Future<void> _loadProfileData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _logout(context);
        return;
      }

      // Ambil baris data user berdasarkan id_user dari tabel 'users'
      final response = await _supabase
          .from('users')
          .select()
          .eq('id_user', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _userRow = response ?? {};
          // Jika email di tabel database kosong, ambil dari auth user
          _userRow!['email'] = _userRow!['email'] ?? user.email;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat profil: $e')),
        );
      }
    }
  }

  /* ---------- UPLOAD FOTO PROFIL ---------- */
  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image == null) return;

    try {
      setState(() => _isLoading = true);
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final bytes = await image.readAsBytes();
      final fileExt = image.path.split('.').last;
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'avatars/$fileName';

      // Upload file ke Supabase Storage (Bucket: avatars)
      await _supabase.storage.from('avatars').uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: true),
          );

      // Ambil Public URL gambar
      final imageUrl = _supabase.storage.from('avatars').getPublicUrl(filePath);

      // Update kolom 'avatar_url' di tabel 'users'
      await _supabase
          .from('users')
          .update({'avatar_url': imageUrl})
          .eq('id_user', user.id);

      // Muat ulang data profil terbaru
      await _loadProfileData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto profil berhasil diperbarui!')),
        );
      }
    } catch (e) {
      debugPrint('Error upload avatar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengunggah foto: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /* ---------- LOGOUT ---------- */
  Future<void> _logout(BuildContext context) async {
    try {
      await _supabase.auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    } catch (e) {
      debugPrint('Error logout: $e');
    }
  }

  /* ---------- MODAL EDIT PROFILE ---------- */
  void _editProfileSheet(
    BuildContext context,
    String displayName,
    String email,
  ) {
    final nameController = TextEditingController(text: displayName);
    final emailController = TextEditingController(text: email);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            top: 16,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Edit Profile',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Lengkap',
                    prefixIcon: const Icon(
                      Icons.person_outline,
                      color: _primaryColor,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: _primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    final newName = nameController.text.trim();
                    if (newName.isEmpty) return;

                    final user = _supabase.auth.currentUser;
                    if (user != null) {
                      try {
                        // Update tabel users
                        await _supabase
                            .from('users')
                            .update({'nama_lengkap': newName})
                            .eq('id_user', user.id);

                        // Update metadata user di auth
                        await _supabase.auth.updateUser(
                          UserAttributes(data: {'nama_lengkap': newName}),
                        );

                        if (mounted) {
                          setState(() {
                            if (_userRow != null) {
                              _userRow!['nama_lengkap'] = newName;
                            }
                          });
                        }

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profil berhasil diperbarui'),
                            ),
                          );
                        }
                      } catch (e) {
                        debugPrint('Error Update Name: $e');
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal memperbarui nama: $e')),
                          );
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Simpan Perubahan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    foregroundColor: Colors.black54,
                  ),
                  child: const Text('Batal'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /* ---------- BUILD ---------- */
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: _primaryColor)),
      );
    }

    final displayName = _userRow?['nama_lengkap'] ?? 'Pengguna';
    final email = _userRow?['email'] ?? '-';
    final noHp = _userRow?['no_hp'] ?? '-';
    final avatarUrl = _userRow?['avatar_url'];
    final pekerjaanSelesai = _userRow?['pekerjaan_selesai'] ?? 0;
    final rating = _userRow?['rating'] ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDF0E6),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: _brownTextColor),
          onPressed: () {},
        ),
        title: const Text(
          'Profil',
          style: TextStyle(
            color: _brownTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: _brownTextColor),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFDF0E6),
              Color(0xFFFAFAFA),
            ],
            stops: [0.0, 0.4],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 130),
          children: [
            // --- FOTO PROFIL ---
            Align(
              alignment: Alignment.center,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 130,
                    height: 130,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFBE4D4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: avatarUrl != null && avatarUrl.toString().isNotEmpty
                            ? Image.network(
                                avatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildDefaultAvatarIcon(),
                              )
                            : _buildDefaultAvatarIcon(),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickAndUploadAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _brownTextColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- INFORMASI TEKS ---
            Text(
              displayName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C323A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              email,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              noHp,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _brownTextColor,
              ),
            ),
            const SizedBox(height: 24),

            // --- KOTAK STATISTIK ---
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF5FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$pekerjaanSelesai',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _brownTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'PEKERJAAN\nSELESAI',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F9F3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star, color: Colors.green, size: 22),
                        const SizedBox(width: 4),
                        Text(
                          '$rating',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- MENU LIST ---
            _buildMenuCard(
              icon: Icons.person_outline,
              title: 'Edit Profil',
              onTap: () => _editProfileSheet(context, displayName, email),
            ),

            // BANNER MITRA
            _buildPartnerBanner(),

            _buildMenuCard(
              icon: Icons.history,
              title: 'Riwayat Pekerjaan',
              onTap: () {},
            ),
            _buildMenuCard(
              icon: Icons.location_on_outlined,
              title: 'Alamat Tersimpan',
              onTap: () {},
            ),
            _buildMenuCard(
              icon: Icons.help_outline,
              title: 'Bantuan & Pusat Dukungan',
              onTap: () {},
            ),
            _buildMenuCard(
              icon: Icons.settings_outlined,
              title: 'Pengaturan',
              onTap: () {},
            ),
            const SizedBox(height: 24),

            // --- TOMBOL KELUAR SESI ---
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  'Keluar Sesi',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFFFCF5F5),
                  side: BorderSide(
                      color: Colors.red.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ---------- HELPERS ---------- */

  Widget _buildDefaultAvatarIcon() {
    return Container(
      color: Colors.grey[300],
      child: const Icon(
        Icons.person,
        size: 80,
        color: Colors.white,
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _iconBgColor,
          child: Icon(icon, color: Colors.black87),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  Widget _buildPartnerBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.black.withValues(alpha: 0.15),
          child: const Icon(Icons.cases_outlined, color: Colors.black87),
        ),
        title: const Text(
          'Daftar Menjadi Mitra',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        subtitle: const Text(
          'Dapatkan penghasilan tambahan',
          style: TextStyle(
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward, color: Colors.black87),
        onTap: () {},
      ),
    );
  }
}