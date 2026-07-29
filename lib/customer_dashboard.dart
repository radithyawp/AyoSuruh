import 'package:flutter/material.dart';
import 'main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key}); // Key ditambahkan untuk refresh

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final Color primaryBrown = const Color(0xFF8B5A2B);
  final Color primaryOrange = const Color(0xFFF39C12);
  final Color bgGrey = const Color(0xFFFAFAFA);

  // State Variables
  bool _isLoading = true;
  String _userName = 'Pengguna';
  String _userAddress = 'Memuat alamat...';
  List<Map<String, dynamic>> _recentJobs = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  // Fungsi untuk mengambil data dari Supabase
  Future<void> _fetchDashboardData() async {
    try {
      final supabase = Supabase.instance.client;
      
      // Asumsi: Kita menggunakan dummy user ID, atau mengambil dari user yang sedang login
      // final userId = supabase.auth.currentUser?.id;

      // 1. Ambil data profil (Contoh tabel: 'profiles')
      // Ubah query ini sesuai dengan nama tabel dan kolom di Supabase Anda
      final userData = await supabase
          .from('profiles')
          .select('full_name, address')
          .limit(1)
          .maybeSingle();

      // 2. Ambil data pekerjaan terbaru (Contoh tabel: 'jobs')
      // Ubah query ini sesuai dengan nama tabel dan kolom di Supabase Anda
      final jobsData = await supabase
          .from('jobs')
          .select('status, created_at, title, address, price')
          .order('created_at', ascending: false)
          .limit(3); // Ambil 3 pekerjaan terakhir

      if (mounted) {
        setState(() {
          _userName = userData?['full_name'] ?? 'Budi (Dummy)';
          _userAddress = userData?['address'] ?? 'Jl. Default No. 1, Jakarta';
          
          if (jobsData.isNotEmpty) {
            _recentJobs = List<Map<String, dynamic>>.from(jobsData);
          } else {
            // Data dummy jika tabel kosong (Untuk testing)
            _recentJobs = [
              {
                'status': 'Dalam Proses',
                'created_at': '2 Jam Lalu',
                'title': 'Potong Rumput Taman Depan',
                'address': 'Jl. Sudirman No. 12',
                'price': 'Rp 150.000',
              },
              {
                'status': 'Selesai',
                'created_at': 'Kemarin',
                'title': 'Service AC Ruang Tamu',
                'address': 'Jl. Sudirman No. 12',
                'price': 'Rp 250.000',
              }
            ];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching Supabase data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _userName = 'Error Memuat';
          _userAddress = 'Gagal mengambil data';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      appBar: _buildAppBar(),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryOrange))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 130.0),
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
                ],
              ),
            ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90.0),
        child: FloatingActionButton(
          onPressed: () {
            // TODO: Aksi tambah pesanan baru
          },
          backgroundColor: primaryOrange,
          elevation: 4,
          child: const Icon(Icons.add, color: Colors.black87, size: 28),
        ),
      ),
    );
  }

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

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Halo, $_userName!",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: primaryBrown),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _userAddress,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.orange.shade100,
          child: Icon(Icons.person, color: primaryBrown, size: 28),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    // [Kode tidak berubah]
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

  Widget _buildPromoBanner() {
    // [Kode tidak berubah]
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFD6E8D3),
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

  Widget _buildCategorySection() {
    // [Kode tidak berubah]
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
            _categoryItem(Icons.cleaning_services, "Kebersihan",
                Colors.orange.shade100, Colors.orange.shade800),
            _categoryItem(Icons.local_shipping, "Kurir",
                Colors.green.shade50, Colors.green.shade800),
            _categoryItem(Icons.build, "Tukang", Colors.red.shade50,
                Colors.red.shade800),
            _categoryItem(Icons.grid_view, "Lainnya", Colors.grey.shade200,
                Colors.black87),
          ],
        ),
      ],
    );
  }

  Widget _categoryItem(
      IconData icon, String label, Color bgColor, Color iconColor) {
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

  Widget _buildRecentJobsSection() {
    if (_recentJobs.isEmpty) {
      return const SizedBox.shrink(); // Sembunyikan section jika tidak ada data
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Pekerjaan Terbaru",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        // Looping data dari Supabase
        ..._recentJobs.map((job) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _jobCard(
              status: job['status'] ?? 'Menunggu',
              time: job['created_at'] ?? '-',
              title: job['title'] ?? 'Pekerjaan',
              address: job['address'] ?? '-',
              price: job['price']?.toString() ?? 'Rp 0',
            ),
          );
        }),
      ],
    );
  }

  Widget _jobCard({
    required String status,
    required String time,
    required String title,
    required String address,
    required String price,
  }) {
    
    // Menentukan warna secara dinamis berdasarkan status
    Color statusBgColor;
    Color statusTextColor;
    
    if (status.toLowerCase() == 'dalam proses') {
      statusBgColor = Colors.green.shade100;
      statusTextColor = Colors.green.shade800;
    } else if (status.toLowerCase() == 'selesai') {
      statusBgColor = Colors.grey.shade200;
      statusTextColor = Colors.black54;
    } else {
      statusBgColor = Colors.orange.shade100;
      statusTextColor = Colors.orange.shade800;
    }

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
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                      fontSize: 12,
                      color: statusTextColor,
                      fontWeight: FontWeight.bold),
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
              const Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.black54),
            ],
          ),
        ],
      ),
    );
  }
}