import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../jobs/job_helpers.dart';
import 'admin_service.dart';

class AdminMitrasPage extends StatefulWidget {
  const AdminMitrasPage({
    super.key,
    this.initialTab = 0,
  });

  final int initialTab;

  @override
  State<AdminMitrasPage> createState() => _AdminMitrasPageState();
}

class _AdminMitrasPageState extends State<AdminMitrasPage>
    with SingleTickerProviderStateMixin {
  static const Color _brown = Color(0xFF7B4B00);
  static const Color _orange = Color(0xFFFF9800);
  static const Color _green = Color(0xFF5F784F);
  static const Color _background = Color(0xFFFFFAFD);

  final AdminService _service = AdminService();
  late final TabController _tabController;
  List<Map<String, dynamic>> _applications = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _payouts = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == 1 ? 1 : 0,
    );
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
        _service.fetchMitraApplications(),
        _service.fetchPayouts(),
      ]);
      if (!mounted) return;
      setState(() {
        _applications = result[0] as List<Map<String, dynamic>>;
        _payouts = result[1] as List<Map<String, dynamic>>;
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

  Future<void> _reviewApplication(Map<String, dynamic> row, String action) async {
    String? note;
    if (action == 'reject') {
      note = await _askNote(
        title: 'Tolak Pengajuan Mitra',
        hint: 'Tuliskan alasan penolakan...',
        mustFill: true,
      );
      if (note == null) return;
    }

    setState(() => _actionLoading = true);
    try {
      await _service.reviewMitraApplication(
        applicationId: row['application_id'].toString(),
        action: action,
        note: note,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(action == 'approve' ? 'Mitra berhasil disetujui.' : 'Pengajuan mitra ditolak.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aksi admin gagal: $error'), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _processPayout(Map<String, dynamic> row, String action) async {
    String? note;
    if (action == 'reject') {
      note = await _askNote(
        title: 'Tolak Pencairan',
        hint: 'Alasan penolakan...',
        mustFill: true,
      );
      if (note == null) return;
    }
    setState(() => _actionLoading = true);
    try {
      await _service.processPayout(
        payoutId: row['payout_id'].toString(),
        action: action,
        note: note,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payout belum dapat diproses: $error'), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _previewDocument({
    required String title,
    required Object? storagePath,
  }) async {
    final String path = (storagePath ?? '').toString().trim();
    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title belum tersedia.')),
      );
      return;
    }

    try {
      final String url = await _service.createSignedMitraDocumentUrl(path);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (
                        BuildContext context,
                        Widget child,
                        ImageChunkEvent? progress,
                      ) {
                        if (progress == null) return child;
                        return const SizedBox(
                          height: 320,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (_, _, _) => const Padding(
                        padding: EdgeInsets.all(28),
                        child: Text('Dokumen tidak dapat ditampilkan.'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dokumen belum dapat dibuka: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<String?> _askNote({
    required String title,
    required String hint,
    required bool mustFill,
  }) async {
    String value = '';
    String? validationMessage;

    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (
            BuildContext dialogContext,
            StateSetter setDialogState,
          ) {
            return AlertDialog(
              title: Text(title),
              content: TextField(
                autofocus: true,
                minLines: 3,
                maxLines: 5,
                onChanged: (String text) {
                  value = text;
                  if (validationMessage != null && text.trim().isNotEmpty) {
                    setDialogState(() => validationMessage = null);
                  }
                },
                decoration: InputDecoration(
                  hintText: hint,
                  errorText: validationMessage,
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () {
                    final String trimmed = value.trim();
                    if (mustFill && trimmed.isEmpty) {
                      setDialogState(
                        () => validationMessage = 'Alasan wajib diisi.',
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, trimmed);
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    // Future showDialog dapat selesai sebelum animasi reverse route benar-benar
    // lepas dari tree. Beri satu jeda pendek sebelum halaman induk di-setState
    // atau direfresh agar dependency dialog tidak ikut ter-deactivate paksa.
    if (result != null) {
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
              child: Row(
                children: <Widget>[
                  if (Navigator.of(context).canPop()) ...<Widget>[
                    IconButton(
                      tooltip: 'Kembali',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: _brown,
                      ),
                    ),
                    const SizedBox(width: 2),
                  ],
                  const Expanded(
                    child: Text(
                      'Manajemen Mitra',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _brown),
                    ),
                  ),
                  IconButton(onPressed: _actionLoading ? null : _load, icon: const Icon(Icons.refresh_rounded, color: _brown)),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: _brown,
              unselectedLabelColor: Colors.black45,
              indicatorColor: _orange,
              tabs: const <Tab>[
                Tab(text: 'Verifikasi'),
                Tab(text: 'Pencairan'),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 11)),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _orange))
                  : TabBarView(
                      controller: _tabController,
                      children: <Widget>[
                        _applicationsList(),
                        _payoutList(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _applicationsList() {
    if (_applications.isEmpty) return const Center(child: Text('Belum ada pengajuan mitra.'));
    return RefreshIndicator(
      color: _orange,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        itemCount: _applications.length,
        itemBuilder: (BuildContext context, int index) {
          final Map<String, dynamic> row = _applications[index];
          final String status = (row['status'] ?? '').toString().toLowerCase();
          final bool pending = status == 'applied';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: const Color(0xFFEDE3DC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const CircleAvatar(
                      backgroundColor: Color(0xFFFFE8C6),
                      child: Icon(Icons.badge_outlined, color: _brown),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text((row['fullname'] ?? 'Calon Mitra').toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
                          Text((row['email'] ?? '-').toString(), style: const TextStyle(fontSize: 10.5, color: Color(0xFF71665F))),
                        ],
                      ),
                    ),
                    _statusPill(status),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Alamat: ${(row['address'] ?? '-').toString()}', style: const TextStyle(fontSize: 11, height: 1.35)),
                const SizedBox(height: 3),
                Text('Rekening: ${(row['bank_name'] ?? '-').toString()} • ${(row['account_number'] ?? '-').toString()}', style: const TextStyle(fontSize: 11)),
                if ((row['description'] ?? '').toString().trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 5),
                  Text((row['description'] ?? '').toString(), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: Color(0xFF6D625B))),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: () => _previewDocument(
                        title: 'KTM / Identitas Mitra',
                        storagePath: row['ktm_url'],
                      ),
                      icon: const Icon(Icons.badge_outlined, size: 17),
                      label: const Text('Lihat KTM'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _previewDocument(
                        title: 'Selfie Mitra',
                        storagePath: row['selfie_url'],
                      ),
                      icon: const Icon(Icons.face_retouching_natural, size: 17),
                      label: const Text('Lihat Selfie'),
                    ),
                  ],
                ),
                if (pending) ...<Widget>[
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _actionLoading ? null : () => _reviewApplication(row, 'reject'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
                          child: const Text('Tolak'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: _actionLoading ? null : () => _reviewApplication(row, 'approve'),
                          style: FilledButton.styleFrom(backgroundColor: _orange),
                          child: const Text('Setujui'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _payoutList() {
    if (_payouts.isEmpty) return const Center(child: Text('Belum ada permintaan pencairan.'));
    return RefreshIndicator(
      color: _orange,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        itemCount: _payouts.length,
        itemBuilder: (BuildContext context, int index) {
          final Map<String, dynamic> row = _payouts[index];
          final String status = (row['status'] ?? '').toString().toLowerCase();
          final bool active = <String>{'requested', 'under_review', 'approved', 'processing'}.contains(status);
          final DateTime? date = DateTime.tryParse((row['requested_at'] ?? '').toString())?.toLocal();
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: const Color(0xFFEDE3DC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const CircleAvatar(
                      backgroundColor: Color(0xFFE8F1E2),
                      child: Icon(Icons.account_balance_wallet_outlined, color: _green),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text((row['mitra_name'] ?? 'Mitra').toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
                          if (date != null)
                            Text(DateFormat('dd MMM yyyy, HH:mm').format(date), style: const TextStyle(fontSize: 9.5, color: Colors.black45)),
                        ],
                      ),
                    ),
                    _statusPill(status),
                  ],
                ),
                const SizedBox(height: 10),
                Text(formatRupiah(row['amount']), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _brown)),
                Text('${(row['bank_name'] ?? '').toString()} • ${(row['account_number'] ?? '').toString()}', style: const TextStyle(fontSize: 11)),
                Text((row['account_holder'] ?? '').toString(), style: const TextStyle(fontSize: 10.5, color: Color(0xFF71665F))),
                if (active) ...<Widget>[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: <Widget>[
                      if (status == 'requested')
                        OutlinedButton(onPressed: _actionLoading ? null : () => _processPayout(row, 'review'), child: const Text('Review')),
                      if (status == 'requested' || status == 'under_review')
                        FilledButton(onPressed: _actionLoading ? null : () => _processPayout(row, 'approve'), style: FilledButton.styleFrom(backgroundColor: _orange), child: const Text('Approve')),
                      if (status == 'approved' || status == 'processing')
                        FilledButton(onPressed: _actionLoading ? null : () => _processPayout(row, 'paid'), style: FilledButton.styleFrom(backgroundColor: _green), child: const Text('Tandai Paid')),
                      OutlinedButton(onPressed: _actionLoading ? null : () => _processPayout(row, 'reject'), style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700), child: const Text('Tolak')),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statusPill(String status) {
    final Color color = status == 'approved' || status == 'paid'
        ? _green
        : status == 'rejected' || status == 'failed'
            ? Colors.red.shade700
            : _orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
      child: Text(status.replaceAll('_', ' '), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color)),
    );
  }
}
