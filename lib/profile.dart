import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  Map<String, dynamic>? _userRow;
  bool _isLoading = true;

  // Warna-warna Utama
  static const Color _primaryOrange = Color(0xFFF39C12);
  static const Color _brownColor = Color(0xFF8B5A2B);
  static const Color _bgGrey = Color(0xFFFAF6F3);

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

      final response = await _supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _userRow = response ?? {};
          _userRow!['email'] = _userRow!['email'] ?? user.email;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
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
    
    // 1. Cukup gunakan fileName sebagai path (JANGAN sertakan 'avatars/')
    final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

    // 2. Upload file ke Supabase Storage (Bucket: avatars)
    await _supabase.storage.from('avatars').uploadBinary(
          fileName, // <-- PERBAIKAN: Gunakan fileName langsung
          bytes,
          fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: true),
        );

    // 3. Ambil Public URL gambar
    final imageUrl = _supabase.storage.from('avatars').getPublicUrl(fileName);

    // 4. Update kolom 'avatar_url' di tabel 'users'
    await _supabase
        .from('users')
        .update({'avatar_url': imageUrl})
        .eq('id', user.id);

    // 5. Muat ulang data profil terbaru
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
  void _editProfileSheet(String displayName, String email) {
    final nameController = TextEditingController(text: displayName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Edit Profil',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Lengkap',
                  prefixIcon: const Icon(Icons.person_outline, color: _primaryOrange),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final newName = nameController.text.trim();
                    if (newName.isEmpty) return;

                    final user = _supabase.auth.currentUser;
                    if (user != null) {
                      await _supabase.from('users').update({'fullname': newName}).eq('id', user.id);
                      await _supabase.auth.updateUser(UserAttributes(data: {'fullname': newName}));
                      
                      if (mounted) {
                        setState(() => _userRow!['fullname'] = newName);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryOrange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Simpan Perubahan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /* ---------- BUILD METHOD ---------- */
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: _primaryOrange)),
      );
    }

    final String displayName = _userRow?['fullname'] ?? 'Pengguna';
    final String email = _userRow?['email'] ?? '-';
    final String phone = _userRow?['phone'] ?? '-';
    final String? avatarUrl = _userRow?['avatar_url'];
    final String role = (_userRow?['role'] ?? 'customer').toString().toLowerCase();

    final bool isMitra = role == 'mitra';

    return Scaffold(
      backgroundColor: _bgGrey,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
        child: Column(
          children: [
            // --- HEADER AVATAR & AKUN ---
            _buildProfileHeader(displayName, email, phone, avatarUrl, isMitra),
            const SizedBox(height: 24),

            // --- TAMPILAN DINAMIS BERDASARKAN ROLE ---
            if (isMitra) ...[
              _buildMitraStatsCard(),
              const SizedBox(height: 16),
              _buildSaldoCard(title: "PENDAPATAN MITRA", buttonText: "Cairkan"),
              const SizedBox(height: 16),
              _buildMenuCard(Icons.history, 'Riwayat Pekerjaan Mitra', () {}),
              _buildMenuCard(Icons.edit_outlined, 'Edit Profil', () => _editProfileSheet(displayName, email)),
              _buildMenuCard(Icons.account_balance_wallet_outlined, 'Rekening Bank', () {}),
            ] else ...[
              _buildSaldoCard(title: "SALDO AYOPAY", buttonText: "Isi Saldo"),
              const SizedBox(height: 16),
              _buildMenuCard(Icons.history, 'Riwayat Transaksi', () {}),
              _buildMenuCard(Icons.person_outline, 'Edit Profil', () => _editProfileSheet(displayName, email)),
              _buildPartnerBanner(),
            ],

            // --- MENU UMUM ---
            _buildMenuCard(Icons.help_outline, 'Bantuan & Pusat Dukungan', () {}),
            _buildMenuCard(Icons.settings_outlined, 'Pengaturan', () {}),
            const SizedBox(height: 24),

            // --- TOMBOL KELUAR SESI ---
            _buildLogoutButton(),
            const SizedBox(height: 20),

            // --- VERSION FOOTER ---
            Text(
              'Ayo Suruh v2.4.0',
              style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  /* ---------- HELPER WIDGETS ---------- */

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          Icon(Icons.directions_run_rounded, color: _primaryOrange, size: 28),
          const SizedBox(width: 8),
          const Text(
            'Profil',
            style: TextStyle(color: _brownColor, fontWeight: FontWeight.bold, fontSize: 22),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, color: Colors.black87, size: 26),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildProfileHeader(String name, String email, String phone, String? avatarUrl, bool isMitra) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFBE4D4),
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[200],
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? const Icon(Icons.person, size: 55, color: Colors.grey)
                    : null,
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
                    color: _brownColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            if (isMitra) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Mitra',
                  style: TextStyle(color: Colors.green.shade800, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ]
          ],
        ),
        const SizedBox(height: 2),
        Text(email, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(phone, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _brownColor)),
      ],
    );
  }

  // Card Saldo AYOPAY (Meniru Mockup Desain)
  Widget _buildSaldoCard({required String title, required String buttonText}) {
    final saldo = _userRow?['saldo']?.toString() ?? '500.000';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF0E6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.account_balance_wallet_outlined, color: _brownColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rp $saldo',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add_circle_outline, size: 16, color: Colors.white),
            label: Text(buttonText, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brownColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }

  // Statisik Khusus Profil Mitra
  Widget _buildMitraStatsCard() {
    final pekerjaanSelesai = _userRow?['pekerjaan_selesai'] ?? 0;
    final rating = _userRow?['rating'] ?? 0.0;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text('$pekerjaanSelesai', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _brownColor)),
                const SizedBox(height: 4),
                const Text('Pekerjaan Selesai', style: TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 22),
                const SizedBox(width: 6),
                Text('$rating', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Banner "Daftar Menjadi Mitra" (Meniru Mockup Desain)
  Widget _buildPartnerBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _primaryOrange,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.work_outline, color: Colors.black87),
        ),
        title: const Text(
          'Daftar Menjadi Mitra',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        subtitle: const Text(
          'Dapatkan penghasilan tambahan',
          style: TextStyle(fontSize: 12, color: Colors.black87),
        ),
        trailing: const Icon(Icons.arrow_forward_rounded, color: Colors.black87),
        onTap: () {
          // TODO: Navigasi ke pendaftaran Mitra
        },
      ),
    );
  }

  Widget _buildMenuCard(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFF7F3F0),
          child: Icon(icon, color: Colors.black87, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
        onTap: onTap,
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () => _logout(context),
        icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
        label: const Text(
          'Keluar Sesi',
          style: TextStyle(color: Colors.red, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFFFF5F5),
          side: BorderSide(color: Colors.red.shade200),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}