import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'create_job_page.dart';
import 'customer_job_detail_page.dart';
import '../notification.dart';
import '../mitra/mitra_application_page.dart';
import '../mitra/mitra_application_service.dart';
import 'mitra_job_detail_page.dart';

import 'job_helpers.dart';
import 'job_service.dart';
import 'job_widgets.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';

class CustomerJobsPage extends StatefulWidget {
  const CustomerJobsPage({
    super.key,
    this.tutorialKey,
    this.tutorialPrimaryActionKey,
  });

  final Key? tutorialKey;
  final Key? tutorialPrimaryActionKey;

  @override
  State<CustomerJobsPage> createState() => _CustomerJobsPageState();
}

class _CustomerJobsPageState extends State<CustomerJobsPage>
    with SingleTickerProviderStateMixin {
  final JobService _jobService = JobService();
  final MitraApplicationService _applicationService = MitraApplicationService();
  late final TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _jobs = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _opportunities = <Map<String, dynamic>>[];
  Map<String, dynamic>? _mitraApplication;
  bool _isActiveMitra = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadJobs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadJobs() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final String userId = _jobService.currentUserId;
      final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
        _jobService.fetchCustomerJobs(),
        _jobService.fetchAvailableJobs(),
        _applicationService.fetchMyApplication(),
        Supabase.instance.client
            .from('mitras')
            .select('is_active')
            .eq('id', userId)
            .maybeSingle(),
      ]);
      if (!mounted) return;
      final Map<String, dynamic>? mitraRow = result[3] is Map
          ? Map<String, dynamic>.from(result[3] as Map)
          : null;
      setState(() {
        _jobs = result[0] as List<Map<String, dynamic>>;
        _opportunities = result[1] as List<Map<String, dynamic>>;
        _mitraApplication = result[2] as Map<String, dynamic>?;
        _isActiveMitra = mitraRow?['is_active'] == true;
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
    if (created == true) await _loadJobs();
  }

  Future<void> _openJob(Map<String, dynamic> job) async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => CustomerJobDetailPage(jobId: job['id'].toString()),
      ),
    );
    if (changed == true) await _loadJobs();
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> activeJobs = _jobs.where((job) {
      return !<String>['completed', 'cancelled'].contains(job['status']);
    }).toList();
    final List<Map<String, dynamic>> historyJobs = _jobs.where((job) {
      return <String>['completed', 'cancelled'].contains(job['status']);
    }).toList();

    return Scaffold(
      backgroundColor: jobBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: jobBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: AyoText(
          'Pekerjaan',
          style: TextStyle(
            color: jobBrownColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: <Widget>[
          NotificationBell(
            color: jobDarkBrownColor,
            activeMode: 'customer',
          ),
          SizedBox(width: 4),
        ],
        bottom: TabBar(
          key: widget.tutorialKey,
          controller: _tabController,
          labelColor: jobBrownColor,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          indicatorColor: jobBrownColor,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: <Widget>[
            Tab(text: AyoI18n.t('Aktif')),
            Tab(text: AyoI18n.t('Peluang')),
            Tab(text: AyoI18n.t('Riwayat')),
          ],
        ),

      ),
      body: _buildBody(activeJobs, historyJobs),
      floatingActionButton: Padding(
        key: widget.tutorialPrimaryActionKey,
        padding: const EdgeInsets.only(bottom: 6),
        child: FloatingActionButton.extended(
          heroTag: 'customer-jobs-create-job-fab',
          onPressed: _openCreateJob,
          backgroundColor: jobOrangeColor,
          foregroundColor: const Color(0xFF513300),
          icon: const Icon(Icons.add_rounded),
          label: const AyoText(
            'Buat Pekerjaan',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    List<Map<String, dynamic>> activeJobs,
    List<Map<String, dynamic>> historyJobs,
  ) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: jobOrangeColor));
    }
    if (_errorMessage != null) {
      return RefreshIndicator(
        color: jobOrangeColor,
        onRefresh: _loadJobs,
        child: ListView(
          children: <Widget>[
            EmptyJobState(
              title: 'Data pekerjaan belum dapat dimuat',
              description: 'Tarik ke bawah untuk mencoba kembali.\n$_errorMessage',
              icon: Icons.cloud_off_rounded,
            ),
          ],
        ),
      );
    }
    return TabBarView(
      controller: _tabController,
      children: <Widget>[
        _jobList(
          activeJobs,
          emptyTitle: 'Belum ada pekerjaan aktif',
          emptyDescription: 'Tekan Buat Pekerjaan untuk mulai mencari mitra.',
        ),
        _opportunityList(),
        _jobList(
          historyJobs,
          emptyTitle: 'Riwayat masih kosong',
          emptyDescription: 'Pekerjaan yang selesai atau dibatalkan akan tampil di sini.',
        ),
      ],
    );
  }

  Future<void> _openOpportunity(Map<String, dynamic> job) async {
    if (_isActiveMitra) {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(
          builder: (_) => MitraJobDetailPage(jobId: job['id'].toString()),
        ),
      );
      await _loadJobs();
      return;
    }

    final String status = (_mitraApplication?['status'] ?? '').toString().toLowerCase();
    final Widget page = _mitraApplication == null || status == 'rejected'
        ? MitraApplicationPage(existingApplication: _mitraApplication)
        : MitraApplicationStatusPage(initialApplication: _mitraApplication);
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
    await _loadJobs();
  }

  Widget _opportunityList() {
    final String applicationStatus =
        (_mitraApplication?['status'] ?? '').toString().toLowerCase();
    final String gateLabel = _isActiveMitra
        ? 'Lihat Detail'
        : applicationStatus == 'applied' || applicationStatus == 'approved'
            ? 'Lihat Status Mitra'
            : applicationStatus == 'rejected'
                ? 'Daftar Ulang Mitra'
                : 'Daftar Mitra untuk Ambil';

    return RefreshIndicator(
      color: jobOrangeColor,
      onRefresh: _loadJobs,
      child: _opportunities.isEmpty
          ? ListView(
              children: <Widget>[
                EmptyJobState(
                  title: 'Belum ada peluang pekerjaan',
                  description: 'Pekerjaan terbuka dari customer akan tampil di sini.',
                  icon: Icons.explore_outlined,
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 100),
              itemCount: _opportunities.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (BuildContext context, int index) {
                if (index == 0) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF3D8AD)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(Icons.explore_rounded, color: jobBrownColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AyoText(
                            _isActiveMitra
                                ? 'Kamu sedang melihat peluang dalam peran Customer. Buka detail untuk mengirim penawaran sebagai Mitra.'
                                : 'Kamu bebas melihat peluang pekerjaan. Untuk mengambil pekerjaan atau mengirim penawaran, aktifkan akun Mitra terlebih dahulu.',
                            style: const TextStyle(fontSize: 11, height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final Map<String, dynamic> job = _opportunities[index - 1];
                return JobListCard(
                  job: job,
                  trailingLabel: gateLabel,
                  subtitle:
                      '${customerName(job)} · ${formatJobDate(job['schedule_date'])}, ${formatJobTime(job['schedule_time'])}',
                  onTap: () => _openOpportunity(job),
                );
              },
            ),
    );
  }

  Widget _jobList(
    List<Map<String, dynamic>> jobs, {
    required String emptyTitle,
    required String emptyDescription,
  }) {
    return RefreshIndicator(
      color: jobOrangeColor,
      onRefresh: _loadJobs,
      child: jobs.isEmpty
          ? ListView(
              children: <Widget>[
                EmptyJobState(title: emptyTitle, description: emptyDescription),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
              itemCount: jobs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (BuildContext context, int index) {
                final Map<String, dynamic> job = jobs[index];
                final int bidCount = embeddedBids(job).where((bid) {
                  return bid['status'] == 'pending';
                }).length;
                final String subtitle =
                    '${formatJobDate(job['schedule_date'])} · ${formatJobTime(job['schedule_time'])}'
                    '${bidCount > 0 ? ' · $bidCount penawaran' : ''}';
                final String status = (job['status'] ?? '').toString();
                final bool hasReview = embeddedReviews(job).isNotEmpty;
                final String trailingLabel = status == 'completed'
                    ? hasReview
                        ? 'Lihat Rating'
                        : 'Beri Rating'
                    : 'Lihat Detail';
                return JobListCard(
                  job: job,
                  subtitle: subtitle,
                  trailingLabel: trailingLabel,
                  onTap: () => _openJob(job),
                );
              },
            ),
    );
  }
}
