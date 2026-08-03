import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import Halaman Terkait
import 'edit_profile.dart';
import 'edit_poto_profile.dart'; // Inklusi khusus untuk edit foto profil
import 'login.dart';
import 'help_center.dart';
import 'pengaturan.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  Map<String, dynamic>? _userRow;
  bool _isLoading = true;

  // Warna-warna Utama Ayo Suruh
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
          _userRow = Map<String, dynamic>.from(response ?? {});
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

  /* ---------- NAVIGASI ---------- */
  
  // Navigasi ke Edit Data Profil (Nama, Telepon, dsb)
  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfilePage(userRow: _userRow ?? {}),
      ),
    );

    if (result == true) {
      _loadProfileData();
    }
  }

  // Navigasi Khusus ke Edit Foto Profil
  Future<void> _navigateToEditPhoto() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditPhotoProfilePage(userRow: _userRow ?? {}),
      ),
    );

    if (result == true) {
      _loadProfileData();
    }
  }

  Future<void> _navigateToHelpCenter() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HelpPage()),
    );
  }

  Future<void> _navigateToPengaturanPage() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PengaturanPage()),
    );
  }

  /* ---------- DIALOG & LOGOUT ---------- */
  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Keluar Akun',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _logout(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

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
            // --- HEADER AVATAR & AKUN (Klik Avatar Untuk Ubah Foto) ---
            _buildProfileHeader(displayName, email, phone, avatarUrl, isMitra),
            const SizedBox(height: 24),

            // --- TAMPILAN DINAMIS BERDASARKAN ROLE ---
            if (isMitra) ...[
              _buildMitraStatsCard(),
              const SizedBox(height: 16),
              _buildSaldoCard(title: "PENDAPATAN MITRA", buttonText: "Cairkan"),
              const SizedBox(height: 16),
              _buildMenuCard(Icons.history, 'Riwayat Pekerjaan Mitra', () {}),
              _buildMenuCard(Icons.edit_outlined, 'Edit Profil', _navigateToEditProfile),
              _buildMenuCard(Icons.account_balance_wallet_outlined, 'Rekening Bank', () {}),
            ] else ...[
              _buildSaldoCard(title: "SALDO AYOPAY", buttonText: "Isi Saldo"),
              const SizedBox(height: 16),
              _buildMenuCard(Icons.history, 'Riwayat Transaksi', () {}),
              _buildMenuCard(Icons.person_outline, 'Edit Profil', _navigateToEditProfile),
              _buildPartnerBanner(),
            ],

            // --- MENU UMUM ---
            _buildMenuCard(Icons.help_outline, 'Bantuan & Pusat Dukungan', _navigateToHelpCenter),
            _buildMenuCard(Icons.settings_outlined, 'Pengaturan', _navigateToPengaturanPage),
            const SizedBox(height: 24),

            // --- TOMBOL KELUAR SESI ---
            _buildLogoutButton(),
            const SizedBox(height: 20),

            // --- FOOTER VERSI ---
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
      title: const Row(
        children: [
          Icon(Icons.directions_run_rounded, color: _primaryOrange, size: 28),
          SizedBox(width: 8),
          Text(
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

  Widget _buildProfileHeader(
      String name, String email, String phone, String? avatarUrl, bool isMitra) {
    return Column(
      children: [
        // Avatar dengan Badge Kamera (Klik untuk ubah foto)
        GestureDetector(
          onTap: _navigateToEditPhoto,
          child: Stack(
            alignment: Alignment.bottomRight,
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
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? const Icon(Icons.person, size: 55, color: Colors.grey)
                      : null,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _primaryOrange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
              ),
            ],
          ),
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

  Widget _buildPartnerBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _primaryOrange,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
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
          onTap: () {},
        ),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
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
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _showLogoutConfirmationDialog,
        icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
        label: const Text(
          'Log out',
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