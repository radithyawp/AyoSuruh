import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MitraDashboardPage extends StatefulWidget {
  const MitraDashboardPage({super.key});

  @override
  State<MitraDashboardPage> createState() => _MitraDashboardPageState();
}

class _MitraDashboardPageState extends State<MitraDashboardPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isUnauthorized = false; // Flag jika role bukan mitra

  // Data State dari Supabase
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _activeJob;
  List<Map<String, dynamic>> _availableJobs = [];

  // Warna Utama (Sesuai Tema Ayo Suruh)
  static const Color _bgGrey = Color(0xFFFAF6F3);
  static const Color _primaryBrown = Color(0xFF8B5A2B);
  static const Color _primaryOrange = Color(0xFFF39C12);
  static const Color _peachCard = Color(0xFFFDF0E6);

  @override
  void initState() {
    super.initState();
    _checkRoleAndFetchData();
  }

  /* ---------------- LOGIKA ROLE GUARD & FETCH DATA ---------------- */
  Future<void> _checkRoleAndFetchData() async {
    try {
      setState(() => _isLoading = true);
      final user = _supabase.auth.currentUser;
      
      if (user == null) {
        if (mounted) Navigator.of(context).pop();
        return;
      }

      // 1. Fetch Profile & Cek Role Pengguna berdasarkan User ID
      final profileRes = await _supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      final String role = (profileRes?['role'] ?? 'user').toString().toLowerCase();

      // 🔒 PROTEKSI ROLE: Jika bukan mitra, blokir akses!
      if (role != 'mitra') {
        if (mounted) {
          setState(() {
            _isUnauthorized = true;
            _isLoading = false;
          });
        }
        return;
      }

      // 2. Fetch Pekerjaan Aktif (khusus Mitra ini)
      final activeJobRes = await _supabase
          .from('jobs')
          .select()
          .eq('mitra_id', user.id)
          .eq('status', 'in_progress')
          .maybeSingle();

      // 3. Fetch Pekerjaan Tersedia
      final availableRes = await _supabase
          .from('jobs')
          .select()
          .eq('status', 'open')
          .order('created_at', ascending: false)
          .limit(5);

      if (mounted) {
        setState(() {
          _userProfile = profileRes ?? {};
          _activeJob = activeJobRes;
          _availableJobs = List<Map<String, dynamic>>.from(availableRes);
          _isUnauthorized = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error role guard / fetching data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /* ---------------- FORMATTER HELPER ---------------- */
  String _formatRupiah(num? amount) {
    if (amount == null) return 'Rp 0';
    return 'Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'ac':
      case 'elektronik':
        return Icons.electrical_services_rounded;
      case 'pindahan':
      case 'kurir':
        return Icons.local_shipping_outlined;
      case 'masak':
      case 'kuliner':
        return Icons.restaurant_rounded;
      default:
        return Icons.work_outline_rounded;
    }
  }

  Color _getCategoryColor(String? category) {
    switch (category?.toLowerCase()) {
      case 'ac':
        return const Color(0xFFFDE8E8);
      case 'pindahan':
        return const Color(0xFFE8F5E9);
      case 'masak':
        return const Color(0xFFFFF4E5);
      default:
        return const Color(0xFFF0F4F8);
    }
  }

  Color _getCategoryIconColor(String? category) {
    switch (category?.toLowerCase()) {
      case 'ac':
        return Colors.redAccent;
      case 'pindahan':
        return Colors.green;
      case 'masak':
        return _primaryOrange;
      default:
        return _primaryBrown;
    }
  }

  /* ---------------- BUILD METHOD ---------------- */
  @override
  Widget build(BuildContext context) {
    // 1. TAMPILAN LOADING
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _bgGrey,
        body: Center(
          child: CircularProgressIndicator(color: _primaryOrange),
        ),
      );
    }

    // 🔒 2. TAMPILAN JIKA ROLE BUKAN MITRA (AKSES DITOLAK)
    if (_isUnauthorized) {
      return Scaffold(
        backgroundColor: _bgGrey,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_outline_rounded, size: 60, color: Colors.red.shade400),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Akses Ditolak',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Text(
                  'Halaman ini khusus untuk Mitra Ayo Suruh. Akun Anda saat ini terdaftar sebagai Pengguna/User.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white),
                  label: const Text('Kembali', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBrown,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 3. TAMPILAN DASHBOARD UTAMA (KHUSUS MITRA)
    return Scaffold(
      backgroundColor: _bgGrey,
      body: RefreshIndicator(
        color: _primaryOrange,
        onRefresh: _checkRoleAndFetchData,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildIncomeCard(),
                const SizedBox(height: 16),
                _buildStatsRow(),
                const SizedBox(height: 24),
                _buildActiveJobSection(),
                const SizedBox(height: 24),
                _buildAvailableJobsSection(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /* ---------------- WIDGET COMPONENTS ---------------- */

  Widget _buildHeader() {
    // Mengambil nama dari kolom 'fullname' (atau 'full_name' sebagai alternatif)
    final String name = _userProfile?['fullname'] ?? 
                        _userProfile?['fullname'] ?? 
                        'Mitra';
    final String? avatarUrl = _userProfile?['avatar_url'];

    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey[300],
          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
              ? NetworkImage(avatarUrl)
              : null,
          child: avatarUrl == null || avatarUrl.isEmpty
              ? const Icon(Icons.person, color: Colors.grey)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Halo, Selamat Datang!',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _primaryBrown,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, color: _primaryBrown, size: 28),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildIncomeCard() {
    final num totalPendapatan = _userProfile?['total_pendapatan'] ?? 0;
    final String persentase = _userProfile?['persentase_pendapatan'] ?? '+0%';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _peachCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Pendapatan',
                style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              Text(
                _formatRupiah(totalPendapatan),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: _primaryBrown,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.trending_up_rounded, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '$persentase dari bulan lalu',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 64,
              color: Colors.black.withOpacity(0.05),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final rating = _userProfile?['rating'] ?? 0.0;
    final pekerjaanSelesai = _userProfile?['pekerjaan_selesai'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 22),
                    const SizedBox(width: 4),
                    Text(
                      '$rating',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Rating Anda', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: Colors.black87, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      '$pekerjaanSelesai',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Selesai', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveJobSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pekerjaan Aktif',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            if (_activeJob != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _primaryOrange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Sedang Berjalan',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_activeJob == null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                'Tidak ada pekerjaan yang sedang berjalan.',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.shade100, width: 1.5),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.work_outline_rounded, color: Colors.green, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _activeJob!['title'] ?? 'Pekerjaan',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Customer: ${_activeJob!['customer_name'] ?? '-'}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  _activeJob!['location'] ?? '-',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryBrown,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Update Status',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _primaryBrown, width: 1.5),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.chat_bubble_outline_rounded, color: _primaryBrown, size: 20),
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAvailableJobsSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pekerjaan Tersedia',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            GestureDetector(
              onTap: () {},
              child: const Text(
                'Lihat Semua',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _primaryBrown),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_availableJobs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                'Belum ada pekerjaan baru tersedia saat ini.',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _availableJobs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final job = _availableJobs[index];
              final category = job['category']?.toString();

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(category),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _getCategoryIcon(category),
                        color: _getCategoryIconColor(category),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job['title'] ?? 'Pekerjaan',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 13, color: Colors.grey[500]),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  job['location'] ?? '-',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            job['price_estimate'] ?? 'Est. Rp -',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _primaryBrown),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}