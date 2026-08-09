import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../jobs/job_helpers.dart';
import 'admin_refunds_tab.dart';
import 'admin_service.dart';

class AdminOperationsPage extends StatefulWidget {
  const AdminOperationsPage({
    super.key,
    this.initialTab = 0,
  });

  final int initialTab;

  @override
  State<AdminOperationsPage> createState() => _AdminOperationsPageState();
}

class _AdminOperationsPageState extends State<AdminOperationsPage>
    with SingleTickerProviderStateMixin {
  static const Color _brown = Color(0xFF7B4B00);
  static const Color _orange = Color(0xFFFF9800);
  static const Color _green = Color(0xFF5F784F);
  static const Color _background = Color(0xFFFFFAFD);

  final AdminService _service = AdminService();
  final TextEditingController _searchController = TextEditingController();
  late final TabController _tabController;

  List<Map<String, dynamic>> _jobs = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _payments = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _refunds = <Map<String, dynamic>>[];
  Map<String, dynamic> _summary = <String, dynamic>{};

  bool _loading = true;
  String? _error;
  String _query = '';
  String _jobFilter = 'aktif';
  String _paymentFilter = 'semua';

  @override
  void initState() {
    super.initState();
    final int initialTab = widget.initialTab < 0
        ? 0
        : (widget.initialTab > 2 ? 2 : widget.initialTab);
    _tabController = TabController(
      length: 3,
      initialIndex: initialTab,
      vsync: this,
    );
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final List<dynamic> result = await Future.wait<dynamic>(
        <Future<dynamic>>[
          _service.fetchOperationalSummary(),
          _service.fetchAdminJobs(),
          _service.fetchAdminPayments(),
          _service.fetchAdminRefunds(),
        ],
      );
      if (!mounted) return;
      setState(() {
        _summary = result[0] as Map<String, dynamic>;
        _jobs = result[1] as List<Map<String, dynamic>>;
        _payments = result[2] as List<Map<String, dynamic>>;
        _refunds = result[3] as List<Map<String, dynamic>>;
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

  List<Map<String, dynamic>> get _filteredJobs {
    final String q = _query.trim().toLowerCase();
    return _jobs.where((Map<String, dynamic> row) {
      final String status = (row['status'] ?? '').toString().toLowerCase();
      if (_jobFilter == 'aktif' &&
          !<String>{'posted', 'waiting_bid', 'accepted', 'on_progress'}
              .contains(status)) {
        return false;
      }
      if (_jobFilter != 'semua' &&
          _jobFilter != 'aktif' &&
          status != _jobFilter) {
        return false;
      }

      if (q.isEmpty) return true;
      final String haystack = <String>[
        (row['title'] ?? '').toString(),
        (row['customer_name'] ?? '').toString(),
        (row['mitra_name'] ?? '').toString(),
        (row['payment_status'] ?? '').toString(),
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  int get _refundActionCount {
    return _refunds.where((Map<String, dynamic> row) {
      final String status =
          (row['refund_status'] ?? '').toString().toLowerCase();
      return <String>{'manual_review', 'processing', 'failed'}.contains(status);
    }).length;
  }

  List<Map<String, dynamic>> get _filteredPayments {
    final String q = _query.trim().toLowerCase();
    return _payments.where((Map<String, dynamic> row) {
      final String status = (row['status'] ?? '').toString().toLowerCase();
      if (_paymentFilter != 'semua' && status != _paymentFilter) return false;

      if (q.isEmpty) return true;
      final String haystack = <String>[
        (row['job_title'] ?? '').toString(),
        (row['customer_name'] ?? '').toString(),
        (row['mitra_name'] ?? '').toString(),
        (row['order_id'] ?? '').toString(),
        (row['transaction_status'] ?? '').toString(),
        (row['payment_type'] ?? '').toString(),
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Row(
                children: <Widget>[
                  if (Navigator.of(context).canPop()) ...<Widget>[
                    IconButton(
                      tooltip: 'Kembali',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded, color: _brown),
                    ),
                    const SizedBox(width: 2),
                  ],
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Monitor Operasional',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: _brown,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Pantau pekerjaan, transaksi, dan refund yang memerlukan tindakan admin.',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF756860),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh_rounded, color: _brown),
                  ),
                ],
              ),
            ),
            if (!_loading) _summaryStrip(),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (String value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Cari job, customer, mitra, order ID, atau alasan refund...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE9DED6)),
                  ),
                ),
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: _brown,
              unselectedLabelColor: Colors.black45,
              indicatorColor: _orange,
              tabs: const <Tab>[
                Tab(text: 'Pekerjaan'),
                Tab(text: 'Transaksi'),
                Tab(text: 'Refund'),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: _notice(
                  _error!,
                  Colors.red.shade50,
                  Colors.red.shade700,
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _orange),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: <Widget>[
                        _jobsTab(),
                        _paymentsTab(),
                        AdminRefundsTab(
                          refunds: _refunds,
                          searchQuery: _query,
                          onChanged: _load,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryStrip() {
    return SizedBox(
      height: 70,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        children: <Widget>[
          _summaryChip(
            'Job Aktif',
            _number('active_jobs'),
            Icons.work_outline_rounded,
          ),
          _summaryChip(
            'Cari Mitra',
            _number('waiting_jobs'),
            Icons.manage_search_rounded,
          ),
          _summaryChip(
            'Dikerjakan',
            _number('in_progress_jobs'),
            Icons.handyman_outlined,
          ),
          _summaryChip(
            'Payment Pending',
            _number('pending_payments'),
            Icons.hourglass_top_rounded,
          ),
          _summaryChip(
            'Payment Paid',
            _number('paid_payments'),
            Icons.payments_outlined,
          ),
          _summaryChip(
            'Refund Review',
            _refundActionCount,
            Icons.manage_search_rounded,
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, num value, IconData icon) {
    return Container(
      width: 132,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE3DC)),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 17,
            backgroundColor: const Color(0xFFFFEBD0),
            child: Icon(icon, size: 17, color: _brown),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    height: 1.1,
                    color: Color(0xFF766A63),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _jobsTab() {
    final List<Map<String, dynamic>> rows = _filteredJobs;
    return Column(
      children: <Widget>[
        _filterScroller(
          children: <Widget>[
            _jobFilterChip('aktif', 'Aktif'),
            _jobFilterChip('semua', 'Semua'),
            _jobFilterChip('posted', 'Posted'),
            _jobFilterChip('waiting_bid', 'Menunggu Bid'),
            _jobFilterChip('accepted', 'Diterima'),
            _jobFilterChip('on_progress', 'Dikerjakan'),
            _jobFilterChip('completed', 'Selesai'),
            _jobFilterChip('cancelled', 'Batal'),
          ],
        ),
        Expanded(
          child: rows.isEmpty
              ? const Center(child: Text('Tidak ada pekerjaan pada filter ini.'))
              : RefreshIndicator(
                  color: _orange,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
                    itemCount: rows.length,
                    itemBuilder: (BuildContext context, int index) =>
                        _jobCard(rows[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _paymentsTab() {
    final List<Map<String, dynamic>> rows = _filteredPayments;
    return Column(
      children: <Widget>[
        _filterScroller(
          children: <Widget>[
            _paymentFilterChip('semua', 'Semua'),
            _paymentFilterChip('pending', 'Pending'),
            _paymentFilterChip('paid', 'Paid'),
            _paymentFilterChip('refunded', 'Refunded'),
            _paymentFilterChip('cancelled', 'Cancelled'),
          ],
        ),
        Expanded(
          child: rows.isEmpty
              ? const Center(child: Text('Tidak ada transaksi pada filter ini.'))
              : RefreshIndicator(
                  color: _orange,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
                    itemCount: rows.length,
                    itemBuilder: (BuildContext context, int index) =>
                        _paymentCard(rows[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _filterScroller({required List<Widget> children}) {
    return SizedBox(
      height: 52,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        scrollDirection: Axis.horizontal,
        children: children,
      ),
    );
  }

  Widget _jobFilterChip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        label: Text(label),
        selected: _jobFilter == value,
        onSelected: (_) => setState(() => _jobFilter = value),
        selectedColor: const Color(0xFFFFE2B6),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w800,
          color: _jobFilter == value ? _brown : Colors.black54,
          fontSize: 10.5,
        ),
        side: const BorderSide(color: Color(0xFFE7D9CF)),
      ),
    );
  }

  Widget _paymentFilterChip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        label: Text(label),
        selected: _paymentFilter == value,
        onSelected: (_) => setState(() => _paymentFilter = value),
        selectedColor: const Color(0xFFE6F0DF),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w800,
          color: _paymentFilter == value ? _green : Colors.black54,
          fontSize: 10.5,
        ),
        side: const BorderSide(color: Color(0xFFE7D9CF)),
      ),
    );
  }

  Widget _jobCard(Map<String, dynamic> row) {
    final String status = (row['status'] ?? '').toString().toLowerCase();
    final String progress = (row['progress_stage'] ?? '').toString();
    final DateTime? created =
        DateTime.tryParse((row['created_at'] ?? '').toString())?.toLocal();
    final String mitra = (row['mitra_name'] ?? '').toString().trim();
    final String paymentStatus =
        (row['payment_status'] ?? 'belum ada').toString().trim();

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                backgroundColor: jobStatusBackground(status),
                child: Icon(
                  Icons.work_outline_rounded,
                  color: jobStatusForeground(status),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      (row['title'] ?? 'Pekerjaan').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Customer: ${(row['customer_name'] ?? '-').toString()}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF71665F),
                      ),
                    ),
                  ],
                ),
              ),
              _statusPill(
                jobStatusLabel(status),
                jobStatusForeground(status),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _detailItem(
                  'Budget',
                  formatRupiah(row['budget']),
                ),
              ),
              Expanded(
                child: _detailItem(
                  'Penawaran',
                  '${(row['bid_count'] ?? 0).toString()} bid',
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: <Widget>[
              Expanded(
                child: _detailItem(
                  'Mitra',
                  mitra.isEmpty ? 'Belum terpilih' : mitra,
                ),
              ),
              Expanded(
                child: _detailItem(
                  'Payment',
                  paymentStatus.replaceAll('_', ' '),
                ),
              ),
            ],
          ),
          if (progress.isNotEmpty) ...<Widget>[
            const SizedBox(height: 7),
            _detailItem('Tahap progres', _progressLabel(progress)),
          ],
          if (created != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Dibuat ${DateFormat('dd MMM yyyy, HH:mm').format(created)}',
              style: const TextStyle(fontSize: 9.5, color: Colors.black45),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paymentCard(Map<String, dynamic> row) {
    final String status = (row['status'] ?? 'pending').toString().toLowerCase();
    final Color statusColor = _paymentStatusColor(status);
    final DateTime? updated =
        DateTime.tryParse((row['updated_at'] ?? '').toString())?.toLocal();
    final String orderId = (row['order_id'] ?? '').toString().trim();
    final String transactionStatus =
        (row['transaction_status'] ?? '').toString().trim();
    final String paymentType = (row['payment_type'] ?? '').toString().trim();
    final bool required = row['payment_required'] == true;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                backgroundColor: statusColor.withValues(alpha: 0.12),
                child: Icon(Icons.payments_outlined, color: statusColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      (row['job_title'] ?? 'Transaksi').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (row['customer_name'] ?? '-').toString(),
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF71665F),
                      ),
                    ),
                  ],
                ),
              ),
              _statusPill(status.toUpperCase(), statusColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            formatRupiah(row['amount']),
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: _brown,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: <Widget>[
              Expanded(
                child: _detailItem(
                  'Fee Platform',
                  formatRupiah(row['platform_fee_amount']),
                ),
              ),
              Expanded(
                child: _detailItem(
                  'Net Mitra',
                  formatRupiah(row['mitra_net_amount']),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: <Widget>[
              Expanded(
                child: _detailItem(
                  'Metode',
                  paymentType.isEmpty ? '-' : paymentType,
                ),
              ),
              Expanded(
                child: _detailItem(
                  'Gateway',
                  transactionStatus.isEmpty ? '-' : transactionStatus,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          _detailItem(
            'Payment gate',
            required ? 'Wajib untuk job ini' : 'Belum diwajibkan',
          ),
          if (orderId.isNotEmpty) ...<Widget>[
            const SizedBox(height: 7),
            SelectableText(
              'Order ID: $orderId',
              style: const TextStyle(
                fontSize: 9.5,
                color: Color(0xFF71665F),
              ),
            ),
          ],
          if (updated != null) ...<Widget>[
            const SizedBox(height: 7),
            Text(
              'Update ${DateFormat('dd MMM yyyy, HH:mm').format(updated)}',
              style: const TextStyle(fontSize: 9.5, color: Colors.black45),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              color: Colors.black38,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF554A44),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Color _paymentStatusColor(String status) {
    switch (status) {
      case 'paid':
        return _green;
      case 'refunded':
        return Colors.blue.shade700;
      case 'cancelled':
        return Colors.red.shade700;
      default:
        return _orange;
    }
  }

  String _progressLabel(String stage) {
    switch (stage) {
      case 'heading_to_location':
        return 'Menuju lokasi';
      case 'arrived':
        return 'Tiba di lokasi';
      case 'working':
        return 'Sedang bekerja';
      case 'completion_submitted':
        return 'Menunggu konfirmasi customer';
      default:
        return stage.replaceAll('_', ' ');
    }
  }

  Widget _notice(String text, Color background, Color foreground) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10.5, color: foreground, height: 1.35),
      ),
    );
  }
}
