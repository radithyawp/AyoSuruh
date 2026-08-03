import 'package:flutter/material.dart';

class TentangAyoSuruhPage extends StatelessWidget {
  const TentangAyoSuruhPage({super.key});

  final Color primaryBrown = const Color(0xFF8B5A2B);
  final Color bgGrey = const Color(0xFFFAF7F7);

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
          'Tentang ayo suruh',
          style: TextStyle(
            color: primaryBrown,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        titleSpacing: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo Aplikasi & Versi
            _buildAppLogoSection(),
            const SizedBox(height: 24),

            // Card Misi Kami
            _buildMisiCard(),
            const SizedBox(height: 16),

            // Feature Card 1: Membantu Kebutuhan Harian
            _buildFeatureCard(
              bgColor: const Color(0xFFF1F6EE),
              borderColor: const Color(0xFFE2EFE0),
              iconBgColor: const Color(0xFFD6EAD2),
              iconColor: const Color(0xFF4CA649),
              icon: Icons.volunteer_activism_outlined,
              title: 'Membantu Kebutuhan Harian',
              description:
                  'Solusi praktis untuk belanja, pengantaran, dan bantuan jasa lainnya.',
            ),
            const SizedBox(height: 12),

            // Feature Card 2: Pemberdayaan Mitra Lokal
            _buildFeatureCard(
              bgColor: const Color(0xFFFFF6ED),
              borderColor: const Color(0xFFFDE4D0),
              iconBgColor: const Color(0xFFFDE1C7),
              iconColor: const Color(0xFFE67E22),
              icon: Icons.groups_outlined,
              title: 'Pemberdayaan Mitra Lokal',
              description:
                  'Mendukung pertumbuhan ekonomi komunitas melalui kemitraan yang adil.',
            ),
            const SizedBox(height: 12),

            // Feature Card 3: Transaksi Aman & Transparan
            _buildFeatureCard(
              bgColor: const Color(0xFFF3EFF1),
              borderColor: const Color(0xFFE8DFE3),
              iconBgColor: const Color(0xFF9E8A91),
              iconColor: Colors.white,
              icon: Icons.verified_user_outlined,
              title: 'Transaksi Aman & Transparan',
              description:
                  'Sistem pembayaran terintegrasi dan pelacakan status pesanan secara real-time.',
            ),
            const SizedBox(height: 24),

            // Section Ikuti Kami
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ikuti Kami',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildSocialGroup(context),
            const SizedBox(height: 28),

            // Footer / Copyright
            Text(
              '© 2024 Ayo Suruh. Hak Cipta Dilindungi.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),

            // Link Navigasi Bawah
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    // Navigasi ke Syarat & Ketentuan
                  },
                  child: Text(
                    'Ketentuan Layanan',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primaryBrown,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    '•',
                    style: TextStyle(color: primaryBrown, fontWeight: FontWeight.bold),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    // Navigasi ke Kebijakan Privasi
                  },
                  child: Text(
                    'Kebijakan Privasi',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primaryBrown,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Header Logo & Versi
  Widget _buildAppLogoSection() {
    return Column(
      children: [
        Image.asset(
          'assets/images/logo_ayo_suruh.png', // Sesuaikan path asset logo Anda
          height: 110,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFFDE1C7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.directions_run_rounded,
              size: 60,
              color: primaryBrown,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ayo Suruh',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primaryBrown,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Versi 2.4.1 (Build 108)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // Card Misi Kami
  Widget _buildMisiCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F2F3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MISI KAMI',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: primaryBrown.withOpacity(0.9),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Ayo Suruh adalah platform penghubung terpercaya yang mendekatkan Anda dengan mitra profesional untuk menyelesaikan berbagai tugas harian. Kami hadir untuk memberikan kemudahan bagi pelanggan dan menciptakan peluang ekonomi baru bagi mitra lokal.',
            textAlign: TextAlign.justify,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // Widget Kartu Fitur (3 Poin Utama)
  Widget _buildFeatureCard({
    required Color bgColor,
    required Color borderColor,
    required Color iconBgColor,
    required Color iconColor,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Group Media Sosial / Kontak
  Widget _buildSocialGroup(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F2F2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildSocialTile(
            icon: Icons.language,
            title: 'Website Resmi',
            onTap: () {},
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200, indent: 50),
          _buildSocialTile(
            icon: Icons.camera_alt_outlined,
            title: 'Instagram',
            onTap: () {},
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200, indent: 50),
          _buildSocialTile(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'WhatsApp',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  // Tile Item Media Sosial
  Widget _buildSocialTile({
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
}