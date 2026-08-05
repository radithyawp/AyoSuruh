import 'package:flutter/material.dart';

import 'job_helpers.dart';
import 'job_service.dart';
import 'job_widgets.dart';
import 'mitra_job_detail_page.dart';

class MitraJobHistoryPage extends StatefulWidget {
  const MitraJobHistoryPage({super.key});

  @override
  State<MitraJobHistoryPage> createState() => _MitraJobHistoryPageState();
}

class _MitraJobHistoryPageState extends State<MitraJobHistoryPage> {
  final JobService _jobService = JobService();

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _history = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<Map<String, dynamic>> result =
          await _jobService.fetchMitraJobHistory();
      if (!mounted) return;
      setState(() {
        _history = result;
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

  Future<void> _openDetail(String jobId) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => MitraJobDetailPage(jobId: jobId),
      ),
    );
    if (mounted) await _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: jobBackgroundColor,
      appBar: AppBar(
        backgroundColor: jobBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: jobBrownColor),
        ),
        title: const Text(
          'Riwayat Pekerjaan Mitra',
          style: TextStyle(
            color: jobBrownColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: jobOrangeColor),
      );
    }

    if (_errorMessage != null) {
      return RefreshIndicator(
        color: jobOrangeColor,
        onRefresh: _loadHistory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            EmptyJobState(
              title: 'Riwayat belum dapat dimuat',
              description: 'Tarik ke bawah untuk mencoba lagi.\n$_errorMessage',
              icon: Icons.cloud_off_rounded,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: jobOrangeColor,
      onRefresh: _loadHistory,
      child: _history.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const <Widget>[
                EmptyJobState(
                  title: 'Belum ada riwayat pekerjaan',
                  description:
                      'Pekerjaan yang selesai atau dibatalkan akan tampil di sini.',
                  icon: Icons.history_rounded,
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
              itemCount: _history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (BuildContext context, int index) {
                final Map<String, dynamic> job = _history[index];
                final bool completed = job['status'] == 'completed';
                final List<Map<String, dynamic>> reviews = embeddedReviews(job);
                final String? ratingLabel = reviews.isEmpty
                    ? null
                    : '${reviews.first['rating']}/5';
                return JobListCard(
                  job: job,
                  subtitle:
                      'Customer: ${customerName(job)} · ${formatJobDate(job['schedule_date'])}'
                      '${ratingLabel == null ? '' : ' · Rating $ratingLabel'}',
                  trailingLabel: completed
                      ? ratingLabel == null
                          ? 'Belum Dinilai'
                          : '★ $ratingLabel'
                      : 'Lihat Detail',
                  onTap: () => _openDetail(job['id'].toString()),
                );
              },
            ),
    );
  }
}
