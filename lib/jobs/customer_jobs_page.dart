import 'package:flutter/material.dart';

import 'create_job_page.dart';
import 'customer_job_detail_page.dart';
import 'job_helpers.dart';
import 'job_service.dart';
import 'job_widgets.dart';
import '../widgets/home_shortcut_button.dart';

class CustomerJobsPage extends StatefulWidget {
  const CustomerJobsPage({super.key});

  @override
  State<CustomerJobsPage> createState() => _CustomerJobsPageState();
}

class _CustomerJobsPageState extends State<CustomerJobsPage>
    with SingleTickerProviderStateMixin {
  final JobService _jobService = JobService();
  late final TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _jobs = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      final List<Map<String, dynamic>> jobs =
          await _jobService.fetchCustomerJobs();
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
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
        title: const Text(
          'Pekerjaan',
          style: TextStyle(
            color: jobDarkBrownColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: jobBrownColor,
          unselectedLabelColor: const Color(0xFF766B65),
          indicatorColor: jobBrownColor,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: const <Widget>[
            Tab(text: 'Aktif'),
            Tab(text: 'Riwayat'),
          ],
        ),

        actions: const <Widget>[HomeShortcutButton()],
      ),
      body: _buildBody(activeJobs, historyJobs),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: FloatingActionButton.extended(
          onPressed: _openCreateJob,
          backgroundColor: jobOrangeColor,
          foregroundColor: const Color(0xFF513300),
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Tambah Pekerjaan',
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
          emptyDescription: 'Tekan Tambah Pekerjaan untuk mulai mencari mitra.',
        ),
        _jobList(
          historyJobs,
          emptyTitle: 'Riwayat masih kosong',
          emptyDescription: 'Pekerjaan yang selesai atau dibatalkan akan tampil di sini.',
        ),
      ],
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
              separatorBuilder: (_, __) => const SizedBox(height: 12),
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
