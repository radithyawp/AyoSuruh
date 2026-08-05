import 'package:flutter/material.dart';

import 'job_helpers.dart';
import 'job_service.dart';
import 'job_widgets.dart';
import 'mitra_job_detail_page.dart';

class MitraJobsPage extends StatefulWidget {
  const MitraJobsPage({super.key});

  @override
  State<MitraJobsPage> createState() => _MitraJobsPageState();
}

class _MitraJobsPageState extends State<MitraJobsPage>
    with SingleTickerProviderStateMixin {
  final JobService _jobService = JobService();
  late final TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _availableJobs = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _bids = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _activeJobs = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
        _jobService.fetchAvailableJobs(),
        _jobService.fetchMitraBids(),
        _jobService.fetchAssignedMitraJobs(),
      ]);
      if (!mounted) return;
      setState(() {
        _availableJobs = result[0] as List<Map<String, dynamic>>;
        _bids = result[1] as List<Map<String, dynamic>>;
        _activeJobs = result[2] as List<Map<String, dynamic>>;
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

  Future<void> _openJob(String jobId) async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => MitraJobDetailPage(jobId: jobId),
      ),
    );
    if (changed == true) await _loadData();
  }

  @override
  Widget build(BuildContext context) {
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
          isScrollable: false,
          labelColor: jobBrownColor,
          unselectedLabelColor: const Color(0xFF766B65),
          indicatorColor: jobBrownColor,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          tabs: const <Widget>[
            Tab(text: 'Tersedia'),
            Tab(text: 'Pengajuan'),
            Tab(text: 'Aktif'),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: jobOrangeColor));
    }
    if (_errorMessage != null) {
      return RefreshIndicator(
        color: jobOrangeColor,
        onRefresh: _loadData,
        child: ListView(
          children: <Widget>[
            EmptyJobState(
              title: 'Data pekerjaan belum dapat dimuat',
              description: 'Tarik ke bawah untuk mencoba lagi.\n$_errorMessage',
              icon: Icons.cloud_off_rounded,
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: <Widget>[
        _availableList(),
        _bidList(),
        _activeList(),
      ],
    );
  }

  Widget _availableList() {
    return RefreshIndicator(
      color: jobOrangeColor,
      onRefresh: _loadData,
      child: _availableJobs.isEmpty
          ? ListView(
              children: <Widget>[
                EmptyJobState(
                  title: 'Belum ada pekerjaan tersedia',
                  description: 'Pekerjaan baru dari customer akan tampil di sini.',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              itemCount: _availableJobs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (BuildContext context, int index) {
                final Map<String, dynamic> job = _availableJobs[index];
                final bool alreadyBid = embeddedBids(job).any((bid) {
                  return bid['mitra_id'] == _jobService.currentUserId;
                });
                return JobListCard(
                  job: job,
                  trailingLabel: alreadyBid ? 'Sudah Mengajukan' : 'Lihat Detail',
                  subtitle:
                      '${customerName(job)} · ${formatJobDate(job['schedule_date'])}, ${formatJobTime(job['schedule_time'])}',
                  onTap: () => _openJob(job['id'].toString()),
                );
              },
            ),
    );
  }

  Widget _bidList() {
    return RefreshIndicator(
      color: jobOrangeColor,
      onRefresh: _loadData,
      child: _bids.isEmpty
          ? ListView(
              children: <Widget>[
                EmptyJobState(
                  title: 'Belum ada pengajuan',
                  description: 'Pilih pekerjaan tersedia lalu kirim penawaranmu.',
                  icon: Icons.send_outlined,
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              itemCount: _bids.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (BuildContext context, int index) {
                final Map<String, dynamic> bid = _bids[index];
                final dynamic rawJob = bid['jobs'];
                if (rawJob is! Map) return const SizedBox.shrink();
                final Map<String, dynamic> job = Map<String, dynamic>.from(rawJob);
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: jobBorderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              job['title'].toString(),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: bid['status'] == 'accepted'
                                  ? const Color(0xFFDCEED1)
                                  : bid['status'] == 'rejected'
                                      ? const Color(0xFFFFDCD8)
                                      : const Color(0xFFFFE8C5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              bidStatusLabel(bid['status']),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: bid['status'] == 'rejected'
                                    ? Colors.red.shade700
                                    : jobGreenColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Penawaran: ${formatRupiah(bid['price'])}',
                        style: const TextStyle(color: jobBrownColor, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Estimasi: ${bid['estimated_time'] ?? '-'}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF70645D)),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _openJob(job['id'].toString()),
                          child: const Text('Lihat Pekerjaan'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _activeList() {
    return RefreshIndicator(
      color: jobOrangeColor,
      onRefresh: _loadData,
      child: _activeJobs.isEmpty
          ? ListView(
              children: <Widget>[
                EmptyJobState(
                  title: 'Belum ada pekerjaan aktif',
                  description: 'Pekerjaan akan masuk ke sini setelah penawaranmu diterima.',
                  icon: Icons.assignment_turned_in_outlined,
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              itemCount: _activeJobs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (BuildContext context, int index) {
                final Map<String, dynamic> job = _activeJobs[index];
                return JobListCard(
                  job: job,
                  trailingLabel: job['status'] == 'accepted' ? 'Mulai Pekerjaan' : 'Lihat Detail',
                  subtitle: 'Customer: ${customerName(job)}',
                  onTap: () => _openJob(job['id'].toString()),
                );
              },
            ),
    );
  }
}
