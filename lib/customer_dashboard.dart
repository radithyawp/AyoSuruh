import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({Key? key}) : super(key: key);

  // Tema warna yang mendekati desain
  final Color primaryBrown = const Color(0xFF8B5A2B);
  final Color primaryOrange = const Color(0xFFF39C12);
  final Color bgGrey = const Color(0xFFFAFAFA);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildSearchBar(),
            const SizedBox(height: 24),
            _buildPromoBanner(),
            const SizedBox(height: 32),
            _buildCategorySection(),
            const SizedBox(height: 32),
            _buildRecentJobsSection(),
            const SizedBox(height: 80), // Padding bawah untuk menghindari FAB
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Aksi tambah pesanan baru
        },
        backgroundColor: primaryOrange,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.black87, size: 28),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // --- KOMPONEN APP BAR ---
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: bgGrey,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.menu, color: primaryBrown),
        onPressed: () {},
      ),
      title: Text(
        "Ayo Suruh",
        style: TextStyle(
          color: primaryBrown,
          fontWeight: FontWeight.w800,
          fontSize: 22,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.black87),
          onPressed: () {},
        ),
      ],
    );
  }

  // --- KOMPONEN HEADER (PROFIL & LOKASI) ---
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Halo, Budi!",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: primaryBrown),
                const SizedBox(width: 4),
                const Text(
                  "Jl. Sudirman No. 12, Jakarta",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        // Gambar dihapus, diganti dengan avatar ikon
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.orange.shade100,
          child: Icon(Icons.person, color: primaryBrown, size: 28),
        ),
      ],
    );
  }

  // --- KOMPONEN KOLOM PENCARIAN ---
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const TextField(
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search, color: Colors.black54),
          hintText: "Cari layanan...",
          hintStyle: TextStyle(color: Colors.black38),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  // --- KOMPONEN BANNER PROMO (Tanpa Gambar) ---
  Widget _buildPromoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFD6E8D3), // Warna hijau sage
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Rumah bersih, hati\nsenang.",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBrown,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              "Pesan Sekarang",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // --- KOMPONEN KATEGORI ---
  Widget _buildCategorySection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Kategori Layanan",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "Lihat Semua",
              style: TextStyle(
                fontSize: 14,
                color: primaryBrown,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _categoryItem(Icons.cleaning_services, "Kebersihan", Colors.orange.shade100, Colors.orange.shade800),
            _categoryItem(Icons.local_shipping, "Kurir", Colors.green.shade50, Colors.green.shade800),
            _categoryItem(Icons.build, "Tukang", Colors.red.shade50, Colors.red.shade800),
            _categoryItem(Icons.grid_view, "Lainnya", Colors.grey.shade200, Colors.black87),
          ],
        ),
      ],
    );
  }

  Widget _categoryItem(IconData icon, String label, Color bgColor, Color iconColor) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: iconColor, size: 32),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // --- KOMPONEN PEKERJAAN TERBARU (Tanpa Gambar Thumbnail) ---
  Widget _buildRecentJobsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Pekerjaan Terbaru",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _jobCard(
          status: "Dalam Proses",
          statusColor: Colors.green.shade100,
          statusTextColor: Colors.green.shade800,
          time: "2 Jam Lalu",
          title: "Potong Rumput Taman Depan",
          address: "Jl. Sudirman No. 12...",
          price: "Rp 150.000",
        ),
        const SizedBox(height: 12),
        _jobCard(
          status: "Selesai",
          statusColor: Colors.grey.shade200,
          statusTextColor: Colors.black54,
          time: "Kemarin",
          title: "Service AC Ruang Tamu",
          address: "Jl. Sudirman No. 12...",
          price: "Rp 250.000",
        ),
      ],
    );
  }

  Widget _jobCard({
    required String status,
    required Color statusColor,
    required Color statusTextColor,
    required String time,
    required String title,
    required String address,
    required String price,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(fontSize: 12, color: statusTextColor, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                time,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            address,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                price,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryBrown,
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black54),
            ],
          ),
        ],
      ),
    );
  }

  // --- KOMPONEN BOTTOM NAVIGATION ---
  Widget _buildBottomNav() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: primaryBrown,
      unselectedItemColor: Colors.black54,
      showUnselectedLabels: true,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Beranda"),
        BottomNavigationBarItem(icon: Icon(Icons.work_outline), label: "Pekerjaan"),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: "Chat"),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profil"),
      ],
    );
  }
}