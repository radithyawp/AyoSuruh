import 'package:flutter/material.dart';
import '../widgets/ayo_snackbar.dart';
import 'package:intl/intl.dart';

import '../jobs/job_helpers.dart';
import '../refunds/refund_helpers.dart';
import 'admin_service.dart';

class AdminRefundsTab extends StatefulWidget {
  const AdminRefundsTab({
    super.key,
    required this.refunds,
    required this.searchQuery,
    required this.onChanged,
  });

  final List<Map<String, dynamic>> refunds;
  final String searchQuery;
  final Future<void> Function() onChanged;

  @override
  State<AdminRefundsTab> createState() => _AdminRefundsTabState();
}

class _AdminRefundsTabState extends State<AdminRefundsTab> {
  static const Color _brown = Color(0xFF7B4B00);
  static const Color _orange = Color(0xFFFF9800);
  static const Color _green = Color(0xFF5F784F);

  final AdminService _service = AdminService();
  String _filter = 'action';
  bool _actionLoading = false;

  List<Map<String, dynamic>> get _filtered {
    final String q = widget.searchQuery.trim().toLowerCase();
    return widget.refunds.where((Map<String, dynamic> row) {
      final String status = (row['refund_status'] ?? '').toString().toLowerCase();
      if (_filter == 'action' &&
          !<String>{'manual_review', 'processing', 'failed'}.contains(status)) {
        return false;
      }
      if (_filter != 'action' && _filter != 'all' && status != _filter) {
        return false;
      }

      if (q.isEmpty) return true;
      final String haystack = <String>[
        (row['job_title'] ?? '').toString(),
        (row['customer_name'] ?? '').toString(),
        (row['customer_email'] ?? '').toString(),
        (row['mitra_name'] ?? '').toString(),
        (row['order_id'] ?? '').toString(),
        (row['reason'] ?? '').toString(),
        status,
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  Future<String?> _askNote({
    required String title,
    required String message,
    required String hint,
    required bool mustFill,
    required String actionLabel,
    Color? actionColor,
  }) async {
    String value = '';
    String? validationMessage;

    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(message, style: const TextStyle(height: 1.4)),
                  const SizedBox(height: 14),
                  TextField(
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
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  style: actionColor == null
                      ? null
                      : FilledButton.styleFrom(backgroundColor: actionColor),
                  onPressed: () {
                    final String trimmed = value.trim();
                    if (mustFill && trimmed.isEmpty) {
                      setDialogState(
                        () => validationMessage = 'Catatan wajib diisi.',
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, trimmed);
                  },
                  child: Text(actionLabel),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }
    return result;
  }

  Future<void> _process(
    Map<String, dynamic> row,
    String action,
  ) async {
    if (_actionLoading) return;

    final bool approve = action == 'refunded';
    final String? note = await _askNote(
      title: approve ? 'Tandai refund selesai?' : 'Tolak permintaan refund?',
      message: approve
          ? 'Gunakan aksi ini hanya setelah refund/cancel benar-benar sudah '
              'dikonfirmasi pada dashboard Midtrans Sandbox. Aksi ini akan '
              'menutup job dan memperbarui ledger bila pendapatan Mitra sudah tercatat.'
          : 'Customer akan menerima alasan penolakan ini. Pastikan alasan singkat, jelas, dan dapat dipertanggungjawabkan.',
      hint: approve
          ? 'Catatan verifikasi (opsional)...'
          : 'Alasan penolakan refund...',
      mustFill: !approve,
      actionLabel: approve ? 'Tandai Selesai' : 'Tolak Refund',
      actionColor: approve ? _green : Colors.red.shade700,
    );
    if (note == null) return;

    setState(() => _actionLoading = true);
    try {
      await _service.processRefund(
        refundId: row['refund_id'].toString(),
        action: action,
        note: note.isEmpty
            ? 'Refund diverifikasi admin melalui dashboard Midtrans.'
            : note,
      );
      await widget.onChanged();
      if (!mounted) return;
      if (approve) {
        AyoSnackBar.success(context, 'Refund ditandai selesai.');
      } else {
        AyoSnackBar.info(context, 'Permintaan refund ditolak.');
      }
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(context, 'Refund belum dapat diproses: $error');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> rows = _filtered;
    return Column(
      children: <Widget>[
        SizedBox(
          height: 52,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              _filterChip('action', 'Perlu Tindakan'),
              _filterChip('all', 'Semua'),
              _filterChip('manual_review', 'Review'),
              _filterChip('failed', 'Gagal'),
              _filterChip('refunded', 'Refunded'),
              _filterChip('rejected', 'Ditolak'),
              _filterChip('cancelled', 'Cancelled'),
            ],
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Tidak ada refund pada filter ini.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: _orange,
                  onRefresh: widget.onChanged,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
                    itemCount: rows.length,
                    itemBuilder: (BuildContext context, int index) {
                      return _refundCard(rows[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: const Color(0xFFFFE2B6),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w800,
          color: _filter == value ? _brown : Colors.black54,
          fontSize: 10.5,
        ),
        side: const BorderSide(color: Color(0xFFE7D9CF)),
      ),
    );
  }

  Widget _refundCard(Map<String, dynamic> row) {
    final String status = (row['refund_status'] ?? '').toString().toLowerCase();
    final Color color = refundStatusColor(status);
    final bool actionable =
        <String>{'manual_review', 'processing', 'failed'}.contains(status);
    final DateTime? requested =
        DateTime.tryParse((row['requested_at'] ?? '').toString())?.toLocal();
    final String walletBucket = (row['wallet_bucket'] ?? '').toString().trim();
    final num walletAmount = _number(row['wallet_earning_amount']);
    final String mitraName = (row['mitra_name'] ?? '').toString().trim();
    final String orderId = (row['order_id'] ?? '').toString().trim();

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
                backgroundColor: refundStatusBackground(status),
                child: Icon(refundStatusIcon(status), color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      (row['job_title'] ?? 'Refund').toString(),
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
              _statusPill(refundStatusLabel(status), color),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            formatRupiah(row['amount']),
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: _brown,
            ),
          ),
          const SizedBox(height: 9),
          _detail('Alasan', (row['reason'] ?? '-').toString()),
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _detail(
                  'Mitra',
                  mitraName.isEmpty ? 'Belum ada' : mitraName,
                ),
              ),
              Expanded(
                child: _detail(
                  'Payment',
                  (row['payment_status'] ?? '-').toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          _detail(
            'Dana Mitra',
            walletAmount == 0
                ? 'Belum dikreditkan ke dompet'
                : '${formatRupiah(walletAmount)} · ${_bucketLabel(walletBucket)}',
            valueColor: walletBucket == 'held' ? _orange : null,
          ),
          if (walletAmount != 0) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1DA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Refund setelah pendapatan Mitra tercatat dapat membuat penyesuaian ledger. Jika dana sudah masuk proses pencairan, admin wajib memeriksa saldo Mitra sebelum menutup kasus.',
                style: TextStyle(fontSize: 10.5, height: 1.4, color: _brown),
              ),
            ),
          ],
          if ((row['status_message'] ?? '').toString().trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            _detail('Status gateway', row['status_message'].toString()),
          ],
          if (orderId.isNotEmpty) ...<Widget>[
            const SizedBox(height: 7),
            SelectableText(
              'Order ID: $orderId',
              style: const TextStyle(fontSize: 9.5, color: Colors.black45),
            ),
          ],
          if (requested != null) ...<Widget>[
            const SizedBox(height: 7),
            Text(
              'Diajukan ${DateFormat('dd MMM yyyy, HH:mm').format(requested)}',
              style: const TextStyle(fontSize: 9.5, color: Colors.black45),
            ),
          ],
          if (actionable) ...<Widget>[
            const SizedBox(height: 13),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _actionLoading
                        ? null
                        : () => _process(row, 'reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                    ),
                    icon: const Icon(Icons.close_rounded, size: 17),
                    label: const Text('Tolak'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _actionLoading
                        ? null
                        : () => _process(row, 'refunded'),
                    style: FilledButton.styleFrom(backgroundColor: _green),
                    icon: const Icon(Icons.verified_rounded, size: 17),
                    label: const Text('Refund Selesai'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _detail(String label, String value, {Color? valueColor}) {
    return Column(
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
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 10.5,
            height: 1.35,
            fontWeight: FontWeight.w700,
            color: valueColor ?? const Color(0xFF554A44),
          ),
        ),
      ],
    );
  }

  Widget _statusPill(String text, Color color) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  num _number(Object? value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _bucketLabel(String bucket) {
    switch (bucket) {
      case 'pending':
        return 'Pending';
      case 'available':
        return 'Tersedia';
      case 'held':
        return 'Ditahan';
      case 'withdrawn':
        return 'Sudah dicairkan';
      default:
        return bucket.isEmpty ? 'Ledger' : bucket;
    }
  }
}
