import 'package:flutter/material.dart';

class SyaratKetentuanPage extends StatelessWidget {
  const SyaratKetentuanPage({super.key});

  final Color primaryBrown = const Color(0xFF8B5A2B);
  final Color primaryOrange = const Color(0xFFF39C12);
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
          'Syarat & Ketentuan',
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
            // Banner Header
            _buildHeaderBanner(),
            const SizedBox(height: 24),

            // Poin 1
            _buildTermItem(
              number: 1,
              title: 'Pendahuluan',
              description:
                  'Selamat datang di Ayo Suruh. Dengan mengakses dan menggunakan aplikasi kami, Anda dianggap telah membaca, memahami, dan menyetujui seluruh isi dalam Syarat & Ketentuan ini. Ayo Suruh adalah platform teknologi yang menghubungkan Pengguna dengan Mitra (Penyedia Jasa) untuk membantu berbagai kebutuhan harian Anda secara efisien.',
            ),

            // Poin 2
            _buildTermItem(
              number: 2,
              title: 'Akun Pengguna',
              description:
                  'Untuk menggunakan layanan penuh kami, Anda wajib membuat akun dengan data yang valid, akurat, dan terbaru. Anda bertanggung jawab penuh atas kerahasiaan kata sandi dan aktivitas yang terjadi di bawah akun Anda.',
            ),

            // Poin 3
            _buildTermItem(
              number: 3,
              title: 'Layanan Ayo Suruh',
              description:
                  'Ayo Suruh bertindak sebagai perantara digital. Transaksi layanan dilakukan langsung antara Pengguna dan Mitra. Kami berupaya memastikan kualitas Mitra melalui sistem verifikasi dan rating.',
              calloutQuote:
                  '"Kami berkomitmen untuk memberikan bantuan tercepat dan terandal melalui fitur suruhan kustom kami."',
            ),

            // Poin 4
            _buildTermItem(
              number: 4,
              title: 'Biaya dan Pembayaran',
              description:
                  'Semua harga yang tertera dalam aplikasi adalah harga final termasuk biaya layanan aplikasi. Pembayaran dapat dilakukan melalui metode yang tersedia.',
            ),

            // Poin 5
            _buildTermItem(
              number: 5,
              title: 'Pembatalan & Pengembalian',
              description:
                  'Pembatalan pesanan dapat dilakukan sebelum Mitra memulai tugas. Jika pembatalan dilakukan saat tugas sedang berjalan, biaya pembatalan atau biaya parsial mungkin akan dikenakan kepada Pengguna.',
            ),

            // Poin 6
            _buildTermItem(
              number: 6,
              title: 'Batasan Tanggung Jawab',
              description:
                  'Data Pribadi Anda aman bersama kami. Kami menggunakan data lokasi dan identitas hanya untuk keperluan operasional layanan Ayo Suruh sesuai dengan peraturan perundang-undangan yang berlaku di Indonesia.',
            ),

            // Poin 7
            _buildTermItem(
              number: 7,
              title: 'Perubahan Ketentuan',
              description:
                  'Ayo Suruh tidak bertanggung jawab atas kerugian tidak langsung, insidental, atau konsekuensial yang timbul dari penggunaan layanan kami, kecuali dalam kasus kelalaian berat yang terbukti secara hukum.',
              isLast: true,
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Banner Header Atas
  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFDE8CD).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Persetujuan Layanan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryBrown,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Terakhir diperbarui: 24 Mei 2024',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.description_outlined,
            size: 38,
            color: primaryBrown.withOpacity(0.25),
          ),
        ],
      ),
    );
  }

  // Widget Item Poin Syarat & Ketentuan
  Widget _buildTermItem({
    required int number,
    required String title,
    required String description,
    String? calloutQuote,
    bool isLast = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Judul dengan Badge Nomor
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
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Deskripsi Poin (Rata Kiri-Kanan / Justify)
        Text(
          description,
          textAlign: TextAlign.justify,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black87,
            height: 1.5,
          ),
        ),

        // Kotak Kutipan/Callout khusus jika ada
        if (calloutQuote != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(color: primaryBrown, width: 4),
              ),
            ),
            child: Text(
              calloutQuote,
              textAlign: TextAlign.justify,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.black87.withOpacity(0.8),
                height: 1.4,
              ),
            ),
          ),
        ],

        // Garis Pemisah Antar Poin
        if (!isLast) ...[
          const SizedBox(height: 20),
          Divider(color: Colors.grey.shade300, height: 1),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}