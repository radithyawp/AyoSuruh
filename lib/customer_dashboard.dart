import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final Color primaryBrown = const Color(0xFF8B5A2B);
  final Color primaryOrange = const Color(0xFFF39C12);
  final Color bgGrey = const Color(0xFFFAFAFA);

  // State Variables
  bool _isLoading = true;
  String _userName = '';
  String _userAddress = '';
  String? _avatarUrl;
  List<Map<String, dynamic>> _recentJobs = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  // Fetch Data dari Supabase berdasarkan user yang sedang login
  Future<void> _fetchDashboardData() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      if (currentUser != null) {
        // 1. Ambil data profil dari tabel 'users' / 'profiles'
        final userData = await supabase
            .from('users')
            .select('nama_lengkap, alamat, avatar_url')
            .eq('id_user', currentUser.id)
            .maybeSingle();

        // 2. Ambil data pekerjaan dari tabel 'jobs'
        final jobsData = await supabase
            .from('jobs')
            .select('id, title, status, created_at, price, image_url, bids_count')
            .eq('user_id', currentUser.id)
            .order('created_at', ascending: false)
            .limit(3);

        if (mounted) {
          setState(() {
            _userName = userData?['nama_lengkap'] ?? 'Pengguna';
            _userAddress = userData?['alamat'] ?? 'Alamat belum diatur';
            _avatarUrl = userData?['avatar_url'];
            _recentJobs = List<Map<String, dynamic>>.from(jobsData);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching Supabase data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
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
                  const SizedBox(height: 20),
                  _buildSearchBar(),
                  const SizedBox(height: 24),
                  _buildPromoBanner(),
                  const SizedBox(height: 28),
                  _buildCategorySection(),
                  const SizedBox(height: 28),
                  _buildRecentJobsSection(),
                ],
              ),
            ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90.0),
        child: FloatingActionButton.extended(
          onPressed: () {
            // TODO: Navigasi ke halaman Buat Pekerjaan
          },
          backgroundColor: primaryOrange,
          elevation: 4,
          icon: const Icon(Icons.add, color: Colors.black87, size: 24),
          label: const Text(
            'Buat Pekerjaan',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          tooltip: 'Buat Pekerjaan',
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: bgGrey,
      elevation: 0,
      title: Row(
        children: [
          // Icon/Logo Ayo Suruh
          Icon(Icons.directions_run_rounded, color: primaryOrange, size: 30),
          const SizedBox(width: 8),
          Text(
            "ayo suruh",
            style: TextStyle(
              color: primaryBrown,
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.black87, size: 26),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const notificationPage()),
            );
          },
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
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: primaryOrange, width: 2),
          ),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: Colors.orange.shade100,
            backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                ? NetworkImage(_avatarUrl!)
                : null,
            child: _avatarUrl == null || _avatarUrl!.isEmpty
                ? Icon(Icons.person, color: primaryBrown, size: 26)
                : null,
          ),
        ),
      ],
    );
  }

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
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFD8EAD3), // Hijau pastel sesuai gambar
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
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
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text(
                    "Pesan Sekarang",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _categoryItem(Icons.cleaning_services, "Kebersihan",
                const Color(0xFFFDE8CD), primaryOrange),
            _categoryItem(Icons.local_shipping, "Kurir",
                const Color(0xFFEAF5EA), Colors.green.shade700),
            _categoryItem(Icons.build_rounded, "Tukang",
                const Color(0xFFFDEAEA), Colors.red.shade400),
            _categoryItem(Icons.grid_view_rounded, "Lainnya",
                const Color(0xFFEFEFEF), Colors.black87),
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
          width: 65,
          height: 65,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: iconColor, size: 28),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Status Pekerjaan Saya",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (_recentJobs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Center(
              child: Text(
                "Belum ada pekerjaan yang dibuat",
                style: TextStyle(color: Colors.black54),
              ),
            ),
          )
        else
          ..._recentJobs.map((job) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _jobCard(job: job),
            );
          }),
      ],
    );
  }

  Widget _jobCard({required Map<String, dynamic> job}) {
    final String title = job['title'] ?? 'Pekerjaan';
    final String status = job['status'] ?? 'Mencari Mitra';
    final String createdAt = job['created_at'] != null ? '2 Jam Lalu' : '-'; // Bisa diformat timeago
    final String price = job['price']?.toString() ?? 'Rp 0';
    final String? imageUrl = job['image_url'];
    final int bidsCount = job['bids_count'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F7), // Sesuai warna background card di gambar
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade100, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gambar Pekerjaan
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 80,
              height: 80,
              color: Colors.grey.shade300,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover)
                  : Icon(Icons.image, color: Colors.grey.shade600, size: 36),
            ),
          ),
          const SizedBox(width: 12),

          // Detail Informasi Pekerjaan
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Status Badge + Waktu
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryOrange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      createdAt,
                      style: const TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Judul Pekerjaan
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),

                // Penawaran Masuk (Sub-info)
                Text(
                  "$bidsCount Penawaran Masuk",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: primaryBrown,
                  ),
                ),
                const SizedBox(height: 6),

                // Harga + Chevron Icon
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
                    Icon(
                      Icons.chevron_right_rounded,
                      color: primaryBrown,
                      size: 22,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}