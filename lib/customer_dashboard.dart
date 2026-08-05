import 'package:flutter/material.dart';

import 'jobs/create_job_page.dart';
import 'jobs/customer_job_detail_page.dart';
import 'jobs/job_helpers.dart';
import 'jobs/job_service.dart';
import 'jobs/job_widgets.dart';
import 'notification.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final JobService _jobService = JobService();

  bool _isLoading = true;
  String? _errorMessage;
  String _userName = 'Pengguna';
  String _userAddress = 'Alamat belum diatur';
  String? _avatarUrl;
  List<Map<String, dynamic>> _recentJobs = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
        _jobService.fetchMyProfile(),
        _jobService.fetchCustomerJobs(),
        _jobService.fetchMyAddresses(),
      ]);
      final Map<String, dynamic>? profile = result[0] as Map<String, dynamic>?;
      final List<Map<String, dynamic>> jobs =
          result[1] as List<Map<String, dynamic>>;
      final List<Map<String, dynamic>> addresses =
          result[2] as List<Map<String, dynamic>>;

      if (!mounted) return;
      setState(() {
        _userName = (profile?['fullname'] ?? 'Pengguna').toString();
        _avatarUrl = profile?['avatar_url']?.toString();
        if (addresses.isNotEmpty) {
          _userAddress = addresses.first['address'].toString();
        } else {
          _userAddress = (profile?['alamat'] ?? 'Alamat belum diatur').toString();
        }
        _recentJobs = jobs.take(3).toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openCreateJob() async {
    final bool? created = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => const CreateJobPage()),
    );
    if (created == true) await _fetchDashboardData();
  }

  Future<void> _openJob(String jobId) async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => CustomerJobDetailPage(jobId: jobId),
      ),
    );
    if (changed == true) await _fetchDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: jobBackgroundColor,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: jobOrangeColor))
          : RefreshIndicator(
              color: jobOrangeColor,
              onRefresh: _fetchDashboardData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
                children: <Widget>[
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE0DD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Sebagian data belum dapat dimuat: $_errorMessage',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  _buildHeader(),
                  const SizedBox(height: 18),
                  _buildSearchBar(),
                  const SizedBox(height: 18),
                  _buildPromoBanner(),
                  const SizedBox(height: 22),
                  _buildCategorySection(),
                  const SizedBox(height: 22),
                  _buildRecentJobsSection(),
                ],
              ),
            ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 78),
        child: FloatingActionButton.extended(
          onPressed: _openCreateJob,
          backgroundColor: jobOrangeColor,
          foregroundColor: const Color(0xFF553600),
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Buat Pekerjaan',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: jobBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: const Text(
        'ayo suruh',
        style: TextStyle(
          color: jobDarkBrownColor,
          fontWeight: FontWeight.w900,
          fontSize: 22,
        ),
      ),
      actions: <Widget>[
        const NotificationBell(color: jobDarkBrownColor),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Halo, $_userName!',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF302A27),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  const Icon(Icons.location_on, size: 14, color: jobBrownColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _userAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF6F645D)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        CircleAvatar(
          radius: 23,
          backgroundColor: const Color(0xFFFFE4BD),
          backgroundImage: _avatarUrl == null || _avatarUrl!.isEmpty
              ? null
              : NetworkImage(_avatarUrl!),
          child: _avatarUrl == null || _avatarUrl!.isEmpty
              ? const Icon(Icons.person, color: jobBrownColor)
              : null,
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: jobBorderColor),
      ),
      child: const TextField(
        enabled: false,
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF746A64)),
          hintText: 'Cari layanan...',
          hintStyle: TextStyle(fontSize: 12, color: Color(0xFF9B918C)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFDDEDCF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Rumah bersih, hati\nsenang.',
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 13),
                FilledButton(
                  onPressed: _openCreateJob,
                  style: FilledButton.styleFrom(
                    backgroundColor: jobBrownColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Pesan Sekarang'),
                ),
              ],
            ),
          ),
          const Icon(Icons.cleaning_services_rounded, size: 72, color: jobGreenColor),
        ],
      ),
    );
  }

  Widget _buildCategorySection() {
    final List<Map<String, dynamic>> categories = <Map<String, dynamic>>[
      <String, dynamic>{'name': 'Kebersihan', 'icon': Icons.cleaning_services_rounded},
      <String, dynamic>{'name': 'Kurir', 'icon': Icons.local_shipping_rounded},
      <String, dynamic>{'name': 'Tukang', 'icon': Icons.handyman_rounded},
      <String, dynamic>{'name': 'Lainnya', 'icon': Icons.grid_view_rounded},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Kategori Layanan',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 13),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: categories.map((Map<String, dynamic> category) {
            return GestureDetector(
              onTap: _openCreateJob,
              child: Column(
                children: <Widget>[
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: categoryBackground(category['name'].toString()),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      category['icon'] as IconData,
                      color: jobDarkBrownColor,
                      size: 25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    category['name'].toString(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRecentJobsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Status Pekerjaan Saya',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (_recentJobs.isEmpty)
          const EmptyJobState(
            title: 'Belum ada pekerjaan',
            description: 'Buat pekerjaan pertama dan mulai menerima penawaran dari mitra.',
          )
        else
          ..._recentJobs.map((Map<String, dynamic> job) {
            final int bidCount = embeddedBids(job).where((bid) {
              return bid['status'] == 'pending';
            }).length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: JobListCard(
                job: job,
                subtitle: bidCount > 0
                    ? '$bidCount penawaran masuk'
                    : '${formatJobDate(job['schedule_date'])} · ${formatJobTime(job['schedule_time'])}',
                onTap: () => _openJob(job['id'].toString()),
              ),
            );
          }),
      ],
    );
  }
}
