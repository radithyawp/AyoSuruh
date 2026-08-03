import 'package:flutter/material.dart';

class KebijakanPage extends StatelessWidget {
  const KebijakanPage({super.key});

  final Color primaryBrown = const Color(0xFF8B5A2B);
  final Color primaryOrange = const Color(0xFFF39C12);
  final Color bgGrey = const Color(0xFFFAF7F7);
  final Color contactBg = const Color(0xFFE1F0D7);
  final Color contactBtn = const Color(0xFF536E44);

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
          'Kebijakan Privasi',
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            _buildHeaderCard(),
            const SizedBox(height: 20),

            // Poin 1
            _buildPolicyCard(
              number: 1,
              title: 'Informasi yang Kami Kumpulkan',
              description:
                  'Kami mengumpulkan informasi yang Anda berikan langsung kepada kami, termasuk nama, alamat email, nomor telepon, dan data lokasi real-time untuk memfasilitasi layanan penjemputan dan pengantaran. Kami juga mengumpulkan data penggunaan aplikasi untuk meningkatkan performa sistem.',
            ),
            const SizedBox(height: 16),

            // Poin 2
            _buildPolicyCard(
              number: 2,
              title: 'Penggunaan Informasi',
              description:
                  'Data Anda digunakan untuk memproses pesanan, berkomunikasi dengan Anda mengenai pembaruan layanan, dan meningkatkan keamanan transaksi. Kami menggunakan enkripsi tingkat tinggi untuk melindungi komunikasi antara Anda dan mitra kami.',
            ),
            const SizedBox(height: 16),

            // Poin 3
            _buildPolicyCard(
              number: 3,
              title: 'Pembagian Informasi',
              description:
                  'Kami tidak menjual data pribadi Anda. Informasi hanya dibagikan kepada mitra pengemudi atau penyedia layanan pihak ketiga yang diperlukan untuk menyelesaikan pesanan Anda, serta untuk mematuhi kewajiban hukum jika diminta oleh otoritas berwenang.',
            ),
            const SizedBox(height: 20),

            // Banner Ilustrasi Keamanan
            _buildIllustrationBanner(),
            const SizedBox(height: 20),

            // Poin 4
            _buildPolicyCard(
              number: 4,
              title: 'Keamanan Data',
              description:
                  'Kami menerapkan protokol enkripsi SSL/TLS dan penyimpanan data terenkripsi untuk menjaga kerahasiaan informasi Anda. Tim keamanan kami memantau sistem 24/7 untuk mencegah akses tidak sah atau kebocoran data.',
            ),
            const SizedBox(height: 16),

            // Poin 5
            _buildPolicyCard(
              number: 5,
              title: 'Hak Pengguna',
              description:
                  'Anda memiliki hak untuk mengakses, memperbarui, atau meminta penghapusan data pribadi Anda kapan saja melalui pengaturan profil atau dengan menghubungi layanan pelanggan Ayo Suruh. Kami berkomitmen untuk memproses permintaan Anda dalam waktu 30 hari kerja.',
            ),
            const SizedBox(height: 16),

            // Poin 6
            _buildPolicyCard(
              number: 6,
              title: 'Cookies dan Pelacakan',
              description:
                  'Aplikasi kami menggunakan cookies dan teknologi serupa untuk mengingat preferensi Anda dan memberikan pengalaman yang lebih personal. Anda dapat mengatur peramban atau perangkat Anda untuk menolak cookies, namun beberapa fitur aplikasi mungkin tidak berfungsi optimal.',
            ),
            const SizedBox(height: 16),

            // Poin 7
            _buildPolicyCard(
              number: 7,
              title: 'Perubahan Kebijakan',
              description:
                  'Kami dapat memperbarui kebijakan privasi ini secara berkala. Kami akan memberi tahu Anda melalui notifikasi aplikasi atau email jika terdapat perubahan signifikan yang mempengaruhi hak-hak Anda.',
            ),
            const SizedBox(height: 24),

            // Card Kontak / Pertanyaan Bottom Box
            _buildContactCard(context),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Header atas
  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF2EC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kebijakan Privasi',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 14,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                'Terakhir diperbarui: 24 Mei 2024',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Card Poin Kebijakan (Kotak Putih Terpisah)
  Widget _buildPolicyCard({
    required int number,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: primaryOrange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.justify,
            style: const TextStyle(
              fontSize: 12.5,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // Spanduk Ilustrasi Keamanan
  Widget _buildIllustrationBanner() {
    return Container(
      width: double.infinity,
      height: 150,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.shade50, width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pola Latar Belakang Garis Halus
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: Icon(
                Icons.grid_4x4_rounded,
                size: 200,
                color: Colors.teal.shade300,
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryOrange.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryOrange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'KEBIJAKAN PRIVASI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.black87,
                ),
              ),
              Text(
                'AYO SURUH',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Card Hijau "Punya Pertanyaan?"
  Widget _buildContactCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: contactBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'Punya pertanyaan?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Hubungi tim kepatuhan data kami jika Anda memerlukan klarifikasi lebih lanjut.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black87.withOpacity(0.8),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 42,
            child: ElevatedButton(
              onPressed: () {
                // TODO: Aksi hubungi kami / bantuan
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: contactBtn,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 28),
              ),
              child: const Text(
                'Hubungi Kami',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}