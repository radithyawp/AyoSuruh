import 'package:flutter/material.dart';

import 'admin_service.dart';

class AdminFeedbackPage extends StatefulWidget {
  const AdminFeedbackPage({super.key});

  @override
  State<AdminFeedbackPage> createState() => _AdminFeedbackPageState();
}

class _AdminFeedbackPageState extends State<AdminFeedbackPage> {
  static const Color _brown = Color(0xFF7B4B00);
  static const Color _orange = Color(0xFFF6990E);
  static const Color _green = Color(0xFF5F784F);
  static const Color _background = Color(0xFFFFFAFD);

  final AdminService _service = AdminService();
  Map<String, dynamic> _summary = <String, dynamic>{};
  List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
        _service.fetchFeedbackSummary(),
        _service.fetchFeedback(limit: 200),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = result[0] as Map<String, dynamic>;
        _rows = result[1] as List<Map<String, dynamic>>;
        _loading = false;
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

  List<Map<String, dynamic>> get _visibleRows {
    switch (_filter) {
      case 'bug':
        return _rows.where((Map<String, dynamic> row) => row['found_bug'] == true).toList();
      case 'detractor':
        return _rows.where((Map<String, dynamic> row) => _asInt(row['nps']) <= 6).toList();
      case 'followup':
        return _rows.where((Map<String, dynamic> row) => row['allow_followup'] == true).toList();
      default:
        return _rows;
    }
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _roleLabel(String value) {
    switch (value) {
      case 'mitra':
        return 'Mitra';
      case 'both':
        return 'Customer + Mitra';
      default:
        return 'Customer';
    }
  }

  String _performanceLabel(String value) {
    switch (value) {
      case 'very_smooth':
        return 'Sangat lancar';
      case 'smooth':
        return 'Lancar';
      case 'fair':
        return 'Cukup';
      case 'slow':
        return 'Lambat';
      case 'very_slow':
        return 'Sangat lambat';
      default:
        return value;
    }
  }

  String _formatDate(dynamic raw) {
    final DateTime? parsed = DateTime.tryParse(raw?.toString() ?? '');
    if (parsed == null) return '-';
    final DateTime local = parsed.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _brown),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Masukan Pengguna',
          style: TextStyle(color: _brown, fontSize: 19, fontWeight: FontWeight.w900),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : RefreshIndicator(
              color: _orange,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: <Widget>[
                  if (_error != null) ...<Widget>[
                    _notice(_error!),
                    const SizedBox(height: 12),
                  ],
                  _heroSummary(),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(child: _metric('Kemudahan', '${_number('avg_ease').toStringAsFixed(1)}/5', Icons.touch_app_outlined)),
                      const SizedBox(width: 9),
                      Expanded(child: _metric('UI', '${_number('avg_ui').toStringAsFixed(1)}/5', Icons.palette_outlined)),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: <Widget>[
                      Expanded(child: _metric('Kepercayaan', '${_number('avg_trust').toStringAsFixed(1)}/5', Icons.shield_outlined)),
                      const SizedBox(width: 9),
                      Expanded(child: _metric('Bug report', '${_number('bug_reports').toInt()}', Icons.bug_report_outlined)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7F1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDDE8D5)),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.auto_awesome_rounded, color: _green),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Fitur paling sering dipilih: ${(_summary['top_feature'] ?? 'Belum ada data').toString()}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _green),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text('Jawaban Terbaru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _brown)),
                      ),
                      PopupMenuButton<String>(
                        initialValue: _filter,
                        onSelected: (String value) => setState(() => _filter = value),
                        itemBuilder: (_) => const <PopupMenuEntry<String>>[
                          PopupMenuItem(value: 'all', child: Text('Semua')),
                          PopupMenuItem(value: 'bug', child: Text('Ada bug')),
                          PopupMenuItem(value: 'detractor', child: Text('NPS 0–6')),
                          PopupMenuItem(value: 'followup', child: Text('Boleh follow-up')),
                        ],
                        child: Chip(
                          avatar: const Icon(Icons.filter_list_rounded, size: 16),
                          label: Text(_filterLabel(), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFE8DCD4)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_visibleRows.isEmpty)
                    _empty()
                  else
                    ..._visibleRows.map(_feedbackCard),
                ],
              ),
            ),
    );
  }

  String _filterLabel() {
    switch (_filter) {
      case 'bug':
        return 'Ada bug';
      case 'detractor':
        return 'NPS 0–6';
      case 'followup':
        return 'Follow-up';
      default:
        return 'Semua';
    }
  }

  Widget _heroSummary() {
    final int total = _number('total_feedback').toInt();
    final num nps = _number('nps_score');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: <Color>[Color(0xFFA86808), Color(0xFFD48A20)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Suara Pengguna', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text('Feedback langsung dari aplikasi', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text('$total jawaban', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text('NPS ${nps.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDE3DC)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(color: const Color(0xFFFFE9C8), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 19, color: _brown),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _brown)),
                Text(label, style: const TextStyle(fontSize: 9.8, color: Color(0xFF786E68))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _feedbackCard(Map<String, dynamic> row) {
    final int nps = _asInt(row['nps']);
    final bool bug = row['found_bug'] == true;
    final List<String> features = (row['useful_features'] is List)
        ? (row['useful_features'] as List).map((dynamic value) => value.toString()).toList()
        : <String>[];
    final String contact = (row['contact'] ?? '').toString().trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: const BorderSide(color: Color(0xFFEDE3DC)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: CircleAvatar(
          backgroundColor: bug ? const Color(0xFFFFE0DE) : const Color(0xFFEAF2E5),
          child: Icon(bug ? Icons.bug_report_outlined : Icons.rate_review_outlined, color: bug ? Colors.red.shade700 : _green),
        ),
        title: Text(
          (row['fullname'] ?? 'Pengguna').toString(),
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: _brown),
        ),
        subtitle: Text(
          '${_roleLabel((row['role'] ?? 'customer').toString())} · ${_formatDate(row['created_at'])}',
          style: const TextStyle(fontSize: 9.8, color: Color(0xFF786E68)),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: nps >= 9 ? const Color(0xFFEAF2E5) : (nps <= 6 ? const Color(0xFFFFE0DE) : const Color(0xFFFFEFD4)),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text('NPS $nps', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: _brown)),
        ),
        children: <Widget>[
          _row('Email akun', (row['email'] ?? '-').toString()),
          _row('Kemudahan', '${_asInt(row['ease_rating'])}/5'),
          _row('Cari layanan/job', '${_asInt(row['discoverability_rating'])}/5'),
          _row('UI', '${_asInt(row['ui_rating'])}/5'),
          _row('Kepercayaan', '${_asInt(row['trust_rating'])}/5'),
          _row('Performa', _performanceLabel((row['performance'] ?? '').toString())),
          if (features.isNotEmpty) _textBlock('Fitur paling berguna', features.join(', ')),
          if (bug) _textBlock('Bug yang dilaporkan', (row['bug_details'] ?? '-').toString()),
          _textBlock('Yang disukai', (row['liked'] ?? '-').toString()),
          _textBlock('Yang perlu diperbaiki', (row['improvement'] ?? '-').toString()),
          if (row['allow_followup'] == true) _textBlock('Kontak follow-up', contact.isEmpty ? '(tidak diisi)' : contact),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 105, child: Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF7D726C)))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _brown))),
        ],
      ),
    );
  }

  Widget _textBlock(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 9),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFFFFAF5), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 9.8, fontWeight: FontWeight.w900, color: _brown)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 10.5, height: 1.4, color: Color(0xFF665D57))),
        ],
      ),
    );
  }

  Widget _empty() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFEDE3DC))),
      child: const Column(
        children: <Widget>[
          Icon(Icons.forum_outlined, size: 38, color: Color(0xFFAA9D94)),
          SizedBox(height: 8),
          Text('Belum ada feedback pada filter ini.', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF746A64))),
        ],
      ),
    );
  }

  Widget _notice(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFFE6E4), borderRadius: BorderRadius.circular(14)),
      child: Text(message, style: TextStyle(fontSize: 10.5, color: Colors.red.shade800)),
    );
  }
}
