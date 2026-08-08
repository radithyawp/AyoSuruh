import 'package:flutter/material.dart';

import '../jobs/job_helpers.dart';
import 'admin_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  static const Color _brown = Color(0xFF7B4B00);
  static const Color _orange = Color(0xFFFF9800);
  static const Color _green = Color(0xFF5F784F);
  static const Color _background = Color(0xFFFFFAFD);

  final AdminService _service = AdminService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _summary = <String, dynamic>{};
  Map<String, dynamic> _profile = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
        _service.fetchDashboardSummary(),
        _service.fetchMyProfile(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = result[0] as Map<String, dynamic>;
        _profile = result[1] as Map<String, dynamic>;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  num _number(String key) {
    final dynamic value = _summary[key];
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _orange))
            : RefreshIndicator(
                color: _orange,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text(
                                'Ayo Suruh Admin',
                                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _brown),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Halo, ${(_profile['fullname'] ?? 'Admin').toString()}',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF756860)),
                              ),
                            ],
                          ),
                        ),
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFFFFE5BD),
                          backgroundImage: (_profile['avatar_url'] ?? '').toString().isEmpty
                              ? null
                              : NetworkImage(_profile['avatar_url'].toString()),
                          child: (_profile['avatar_url'] ?? '').toString().isEmpty
                              ? const Icon(Icons.admin_panel_settings_rounded, color: _brown)
                              : null,
                        ),
                      ],
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: 12),
                      _notice(_error!, Colors.red.shade50, Colors.red.shade700),
                    ],
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: <Color>[Color(0xFFA86808), Color(0xFFD48A20)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Pendapatan Platform',
                            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            formatRupiah(_number('platform_revenue')),
                            style: const TextStyle(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'GMV ${formatRupiah(_number('gmv_paid'))} · Take rate transaksi tersimpan di setiap payment',
                            style: const TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(child: _metric('Users', _number('total_users'), Icons.people_outline_rounded, const Color(0xFFFFE8C4))),
                        const SizedBox(width: 10),
                        Expanded(child: _metric('Mitra Aktif', _number('total_mitras'), Icons.verified_outlined, const Color(0xFFE6F0DF))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(child: _metric('Job Aktif', _number('active_jobs'), Icons.work_outline_rounded, const Color(0xFFE7EEFA))),
                        const SizedBox(width: 10),
                        Expanded(child: _metric('Job Selesai', _number('completed_jobs'), Icons.task_alt_rounded, const Color(0xFFE7F2E2))),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Perlu Ditinjau',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _brown),
                    ),
                    const SizedBox(height: 9),
                    _taskCard(
                      icon: Icons.badge_outlined,
                      title: 'Verifikasi Mitra',
                      value: _number('pending_mitra_applications'),
                      color: _orange,
                    ),
                    const SizedBox(height: 8),
                    _taskCard(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Pencairan Menunggu',
                      value: _number('pending_payouts'),
                      color: _green,
                    ),
                    const SizedBox(height: 16),
                    _notice(
                      'Dashboard admin memakai revenue platform (komisi 6%), bukan total GMV. Ini memisahkan omzet transaksi dari pendapatan Ayo Suruh.',
                      const Color(0xFFFFF1DA),
                      _brown,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _metric(String label, num value, IconData icon, Color background) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFEDE3DC)),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(backgroundColor: background, child: Icon(icon, color: _brown, size: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(value.toStringAsFixed(0), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF766A63))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskCard({required IconData icon, required String title, required num value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFEDE3DC)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
            child: Text(value.toStringAsFixed(0), style: TextStyle(fontWeight: FontWeight.w900, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _notice(String text, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(13)),
      child: Text(text, style: TextStyle(fontSize: 11, height: 1.4, color: foreground)),
    );
  }
}
