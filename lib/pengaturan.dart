import 'package:ayosuruh/kebijakan.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'syarat_ketentuan.dart';
import 'change_password.dart';
import 'tentang_ayosuruh.dart';

class PengaturanPage extends StatefulWidget {
  const PengaturanPage({super.key});

  @override
  State<PengaturanPage> createState() => _PengaturanPageState();
}

class _PengaturanPageState extends State<PengaturanPage> {
  final Color primaryBrown = const Color(0xFF8B5A2B);
  final Color bgGrey = const Color(0xFFFAF7F7);
  final Color cardBg = Colors.white;
  final Color profileBg = const Color(0xFFF7F2F2);
  final Color logoutBg = const Color(0xFFFDE8E8);
  final Color logoutText = const Color(0xFFB71C1C);

  String _userName = 'Pengguna';
  String _userEmail = 'email@domain.com';
  String? _avatarUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // Mengambil data profil user dari Supabase
  Future<void> _loadUserProfile() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      if (currentUser != null) {
        final userData = await supabase
            .from('users')
            .select('fullname, avatar_url')
            .eq('id', currentUser.id)
            .maybeSingle();

        if (mounted) {
          setState(() {
            _userName = userData?['fullname'] ?? currentUser.email?.split('@').first ?? 'Pengguna';
            _userEmail = currentUser.email ?? 'email@domain.com';
            _avatarUrl = userData?['avatar_url'];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

    Future<void> _navigateToChangePassword() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePassword()),
    );
  }

    Future<void> _navigateToSyarat() async {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SyaratKetentuanPage() ));
    }

    Future<void> _navigateToTentang() async {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TentangAyoSuruhPage()));
    }

    Future<void> _navigtateToKebijakan() async {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const KebijakanPage()));
    }

  @override
  Widget build(BuildContext context) {
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
          'Pengaturan',
          style: TextStyle(
            color: primaryBrown,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        titleSpacing: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryBrown))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Card
                  _buildProfileCard(),
                  const SizedBox(height: 24),

                  // Section: KEAMANAN
                  _buildSectionTitle('KEAMANAN'),
                  const SizedBox(height: 8),
                  _buildCardGroup([
                    _buildSettingTile(
                      icon: Icons.shield_outlined,
                      title: 'Keamanan Akun',
                      onTap: () {
                        // TODO: Navigasi Keamanan Akun
                      },
                    ),
                    _buildDivider(),
                    _buildSettingTile(
                      icon: Icons.lock_outline,
                      title: 'Ganti Password',
                      onTap: () {
                        _navigateToChangePassword();
                      },
                    ),
                  ]),
                  const SizedBox(height: 20),

                  _buildSectionTitle('PREFERENSI'),
                  const SizedBox(height: 8),
                  _buildCardGroup([
                    _buildSettingTile(
                      icon: Icons.notifications_none_outlined,
                      title: 'Pengaturan Notifikasi',
                      onTap: () {
                        // TODO: Navigasi Pengaturan Notifikasi
                      },
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // Section: INFORMASI
                  _buildSectionTitle('INFORMASI'),
                  const SizedBox(height: 8),
                  _buildCardGroup([
                    _buildSettingTile(
                      icon: Icons.description_outlined,
                      title: 'Syarat & Ketentuan',
                      onTap: () {
                        _navigateToSyarat();
                      },
                    ),
                    _buildDivider(),
                    _buildSettingTile(
                      icon: Icons.verified_user_outlined,
                      title: 'Kebijakan Privasi',
                      onTap: () {
                        _navigtateToKebijakan();
                      },
                    ),
                    _buildDivider(),
                    _buildSettingTile(
                      icon: Icons.info_outline,
                      title: 'Tentang Ayo Suruh',
                      onTap: () {
                        _navigateToTentang();
                      },
                    ),
                  ]),
                  const SizedBox(height: 32),
                  // Version Footer
                  Center(
                    child: Text(
                      'Versi 2.4.1 (Build 108)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // Widget Kartu Profil Us
  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: profileBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.orange.shade100,
            backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                ? NetworkImage(_avatarUrl!)
                : null,
            child: _avatarUrl == null || _avatarUrl!.isEmpty
                ? Icon(Icons.person, color: primaryBrown, size: 30)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _userEmail,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Judul Bagian / Section Header
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: primaryBrown.withOpacity(0.9),
        letterSpacing: 0.8,
      ),
    );
  }

  // Container Pembungkus Item
  Widget _buildCardGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  // Item List Tile
  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: primaryBrown, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: primaryBrown.withOpacity(0.6),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // Garis Pemisah
  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.shade100,
      indent: 52,
    );
  }

}