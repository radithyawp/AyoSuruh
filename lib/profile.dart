import 'package:flutter/material.dart';
import 'package:ayosuruh/login.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  /* ---------- DATA USER (DUMMY) ---------- */
  Map<String, dynamic>? _userRow;
  bool _isLoading = true;
  String _avatarCacheBuster = '';

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

  Future<void> _loadProfileData() async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() {
        _userRow = {
          'nama_lengkap': 'Budi Setiawan',
          'email': 'budi.setiawan@email.com',
          'no_hp': '0812-3456-7890',
          'pekerjaan_selesai': 12,
          'rating': 4.8,
          'avatar_url': 'https://i.pravatar.cc/150?img=11', // Dummy image URL
        };
        _isLoading = false;
      });
    }
  }

  /* ---------- UPLOAD FOTO (DUMMY) ---------- */
  Future<void> _pickAndUploadAvatar() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fitur upload foto belum diimplementasikan'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /* ---------- LOGOUT (DUMMY) ---------- */
  Future<void> _logout(BuildContext context) async {
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  void _editProfileSheet(
    BuildContext context,
    String displayName,
    String email,
  ) {
    // ... [Kode _editProfileSheet sama seperti sebelumnya]
    Navigator.pop(context); // dummy action
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
        backgroundColor: const Color(0xFFFDF0E6), // Sesuai warna atas gradient
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
              Color(0xFFFDF0E6), // Peach muda
              Color(0xFFFAFAFA), // Putih/Abu-abu sangat muda
            ],
            stops: [0.0, 0.4], // Membatasi gradient hanya di bagian atas
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
                      color: const Color(0xFFFBE4D4), // Outer ring
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
                        color: Colors.white, // Inner white border
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: avatarUrl != null
                            ? Image.network(avatarUrl, fit: BoxFit.cover)
                            : Container(
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.person,
                                  size: 80,
                                  color: Colors.white,
                                ),
                              ),
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
                          color: _brownTextColor, // Warna tombol edit coklat
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
                color: Color(0xFF2C323A), // Dark grey
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
                      color: const Color(0xFFFAF5FA), // Light purple bg
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
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
                    padding: const EdgeInsets.symmetric(vertical: 24), // Biar proporsional sama kolom kiri
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F9F3), // Light green bg
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star, color: Colors.green, size: 22),
                        const SizedBox(width: 4),
                        Text(
                          '$rating\n',
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
                  backgroundColor: const Color(0xFFFCF5F5), // Light red/grey bg
                  side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
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

  // Helper untuk List Menu Biasa
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  // Helper untuk Banner Mitra Khusus
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        onTap: () {
          // Navigasi ke halaman mitra
        },
      ),
    );
  }
}