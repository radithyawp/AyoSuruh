import 'package:flutter/material.dart';

import 'jobs/job_helpers.dart';
import 'jobs/job_service.dart';
import 'jobs/job_widgets.dart';
import 'jobs/mitra_job_detail_page.dart';
import 'jobs/mitra_jobs_page.dart';
import 'notification.dart';
import 'services/mitra_services_page.dart';

class MitraDashboardPage extends StatefulWidget {
  const MitraDashboardPage({super.key});

  @override
  State<MitraDashboardPage> createState() => _MitraDashboardPageState();
}

class _MitraDashboardPageState extends State<MitraDashboardPage> {
  final JobService _jobService = JobService();

  bool _isLoading = true;
  bool _isUnauthorized = false;
  String? _errorMessage;
  Map<String, dynamic> _profile = <String, dynamic>{};
  Map<String, dynamic>? _activeJob;
  List<Map<String, dynamic>> _availableJobs = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final String role = await _jobService.getCurrentRole();
      if (role != 'mitra') {
        if (!mounted) return;
        setState(() {
          _isUnauthorized = true;
          _isLoading = false;
        });
        return;
      }

      final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
        _jobService.fetchMitraDashboardProfile(),
        _jobService.fetchAssignedMitraJobs(),
        _jobService.fetchAvailableJobs(),
      ]);
      final List<Map<String, dynamic>> activeJobs =
          result[1] as List<Map<String, dynamic>>;
      final List<Map<String, dynamic>> availableJobs =
          result[2] as List<Map<String, dynamic>>;

      if (!mounted) return;
      setState(() {
        _profile = result[0] as Map<String, dynamic>;
        _activeJob = activeJobs.isEmpty ? null : activeJobs.first;
        _availableJobs = availableJobs.take(3).toList();
        _isUnauthorized = false;
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

  Future<void> _openJob(Map<String, dynamic> job) async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => MitraJobDetailPage(jobId: job['id'].toString()),
      ),
    );
    if (changed == true) await _loadDashboard();
  }

  Future<void> _openAllJobs() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const MitraJobsPage()),
    );
    await _loadDashboard();
  }

  Future<void> _openMyServices() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const MitraServicesPage()),
    );
    if (mounted) await _loadDashboard();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: jobBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: jobOrangeColor)),
      );
    }
    if (_isUnauthorized) {
      return Scaffold(
        backgroundColor: jobBackgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.lock_outline_rounded, size: 58, color: jobBrownColor),
                const SizedBox(height: 14),
                const Text(
                  'Akses Khusus Mitra',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Dashboard ini hanya dapat digunakan oleh akun dengan role mitra.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: jobBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: jobOrangeColor,
          onRefresh: _loadDashboard,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            children: <Widget>[
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
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
              const SizedBox(height: 20),
              _buildIncomeCard(),
              const SizedBox(height: 10),
              _buildStats(),
              const SizedBox(height: 14),
              _buildServiceMarketplaceShortcut(),
              const SizedBox(height: 22),
              _buildActiveJob(),
              const SizedBox(height: 22),
              _buildAvailableJobs(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final String? avatar = _profile['avatar_url']?.toString();
    return Row(
      children: <Widget>[
        CircleAvatar(
          radius: 23,
          backgroundColor: const Color(0xFFFFE5C0),
          backgroundImage: avatar == null || avatar.isEmpty ? null : NetworkImage(avatar),
          child: avatar == null || avatar.isEmpty
              ? const Icon(Icons.person, color: jobBrownColor)
              : null,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Halo, Mitra!',
                style: TextStyle(fontSize: 12, color: Color(0xFF6D625C)),
              ),
              Text(
                (_profile['fullname'] ?? 'Mitra Ayo Suruh').toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: jobBrownColor,
                  fontSize: 21,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const NotificationBell(color: jobBrownColor, size: 28),
      ],
    );
  }

  Widget _buildServiceMarketplaceShortcut() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _openMyServices,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: jobBorderColor),
          ),
          child: const Row(
            children: <Widget>[
              CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFFFFE6BD),
                child: Icon(Icons.storefront_rounded, color: jobBrownColor),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Jasa Saya',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: jobBrownColor,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Publikasikan keahlian agar customer bisa menemukan jasamu.',
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.35,
                        color: Color(0xFF746760),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: jobBrownColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIncomeCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEFE3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC98C)),
      ),
      child: Stack(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Total Pendapatan', style: TextStyle(color: jobDarkBrownColor)),
              const SizedBox(height: 4),
              Text(
                formatRupiah(_profile['total_pendapatan']),
                style: const TextStyle(
                  color: jobBrownColor,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Pendapatan dari pekerjaan yang sudah tercatat',
                style: TextStyle(fontSize: 10, color: Color(0xFF6F6A60)),
              ),
            ],
          ),
          const Positioned(
            right: 2,
            bottom: 0,
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 62,
              color: Color(0x1A6F4300),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final num rating = _profile['rating'] is num
        ? _profile['rating'] as num
        : num.tryParse(_profile['rating']?.toString() ?? '') ?? 0;
    return Row(
      children: <Widget>[
        Expanded(
          child: _statCard(
            icon: Icons.star_rounded,
            value: rating.toStringAsFixed(1),
            label: 'Rating Anda',
            background: const Color(0xFFF7F8F2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            icon: Icons.check_circle_outline_rounded,
            value: (_profile['pekerjaan_selesai'] ?? 0).toString(),
            label: 'Selesai',
            background: const Color(0xFFF1EEF1),
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: jobDarkBrownColor, size: 21),
              const SizedBox(width: 4),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF655A54))),
        ],
      ),
    );
  }

  Widget _buildActiveJob() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const Text('Pekerjaan Aktif', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            if (_activeJob != null)
              JobStatusChip(status: _activeJob!['status']),
          ],
        ),
        const SizedBox(height: 11),
        if (_activeJob == null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: jobBorderColor),
            ),
            child: const Text(
              'Belum ada pekerjaan yang diterima atau sedang berjalan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF756A63)),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: jobBorderColor),
            ),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: categoryBackground(categoryName(_activeJob!)),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        categoryIcon(categoryName(_activeJob!)),
                        color: jobGreenColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _activeJob!['title'].toString(),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Customer: ${customerName(_activeJob!)}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF655B55)),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            jobAddress(_activeJob!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF71665F)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    onPressed: () => _openJob(_activeJob!),
                    style: FilledButton.styleFrom(
                      backgroundColor: jobBrownColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    ),
                    child: Text(
                      _activeJob!['status'] == 'accepted'
                          ? 'Mulai Pekerjaan'
                          : 'Update Status',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAvailableJobs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const Text('Pekerjaan Tersedia', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            TextButton(onPressed: _openAllJobs, child: const Text('Lihat Semua')),
          ],
        ),
        const SizedBox(height: 4),
        if (_availableJobs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: jobBorderColor),
            ),
            child: const Text(
              'Belum ada pekerjaan baru saat ini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF756A63)),
            ),
          )
        else
          ..._availableJobs.map((Map<String, dynamic> job) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openJob(job),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: jobBorderColor),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: categoryBackground(categoryName(job)),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(categoryIcon(categoryName(job)), color: jobDarkBrownColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                job['title'].toString(),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                jobAddress(job),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, color: Color(0xFF6E645E)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Est. ${formatRupiah(job['budget'])}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: jobBrownColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const CircleAvatar(
                          radius: 19,
                          backgroundColor: Colors.transparent,
                          child: Icon(Icons.chevron_right_rounded, color: jobDarkBrownColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
