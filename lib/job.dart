import 'package:flutter/material.dart';

import 'jobs/customer_jobs_page.dart';
import 'jobs/job_helpers.dart';
import 'jobs/job_service.dart';
import 'jobs/mitra_jobs_page.dart';

class JobPage extends StatefulWidget {
  const JobPage({
    super.key,
    this.role,
    this.tutorialKey,
  });

  final String? role;
  final Key? tutorialKey;

  @override
  State<JobPage> createState() => _JobPageState();
}

class _JobPageState extends State<JobPage> {
  final JobService _jobService = JobService();
  String? _role;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final String? initialRole = widget.role?.toLowerCase();
    if (initialRole != null && initialRole.isNotEmpty) {
      _role = initialRole;
    } else {
      _loadRole();
    }
  }

  Future<void> _loadRole() async {
    try {
      final String role = await _jobService.getCurrentRole();
      if (!mounted) return;
      setState(() => _role = role);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: jobBackgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.error_outline_rounded, size: 52, color: jobBrownColor),
                const SizedBox(height: 12),
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _loadRole, child: const Text('Coba Lagi')),
              ],
            ),
          ),
        ),
      );
    }
    if (_role == null) {
      return const Scaffold(
        backgroundColor: jobBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: jobOrangeColor)),
      );
    }
    return _role == 'mitra'
        ? MitraJobsPage(tutorialKey: widget.tutorialKey)
        : CustomerJobsPage(tutorialKey: widget.tutorialKey);
  }
}
