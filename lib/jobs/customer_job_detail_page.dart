import 'package:flutter/material.dart';
import '../widgets/ayo_snackbar.dart';

import '../chats/chat_detail_page.dart';
import '../chats/chat_service.dart';
import '../notifications/notification_service.dart';
import '../location/job_location_map.dart';
import '../payments/job_payment_page.dart';
import '../payments/job_payment_widgets.dart';
import '../payments/payment_service.dart';
import '../payments/payment_helpers.dart';
import 'job_bids_page.dart';
import 'job_helpers.dart';
import 'job_rating_page.dart';
import 'job_review_widgets.dart';
import 'job_progress_widgets.dart';
import 'job_service.dart';
import 'job_widgets.dart';
import '../widgets/home_shortcut_button.dart';
import '../widgets/network_photo_gallery.dart';

class CustomerJobDetailPage extends StatefulWidget {
  const CustomerJobDetailPage({super.key, required this.jobId});

  final String jobId;

  @override
  State<CustomerJobDetailPage> createState() => _CustomerJobDetailPageState();
}

class _CustomerJobDetailPageState extends State<CustomerJobDetailPage> {
  final JobService _jobService = JobService();
  final ChatService _chatService = ChatService();
  final NotificationService _notificationService = NotificationService();
  final PaymentService _paymentService = PaymentService();
  bool _isLoading = true;
  bool _isActionLoading = false;
  bool _isOpeningChat = false;
  String? _errorMessage;
  Map<String, dynamic>? _job;
  Map<String, dynamic>? _review;
  Map<String, dynamic>? _payment;
  List<Map<String, dynamic>> _timelines = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadJob();
  }

  Future<void> _loadJob() async {
    try {
      await _notificationService.markJobNotificationsRead(widget.jobId);
      final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
        _jobService.fetchJob(widget.jobId),
        _jobService.fetchJobTimelines(widget.jobId),
        _jobService.fetchJobReview(widget.jobId),
        _paymentService.fetchJobPayment(widget.jobId),
      ]);
      if (!mounted) return;
      setState(() {
        _job = result[0] as Map<String, dynamic>;
        _timelines = result[1] as List<Map<String, dynamic>>;
        _review = result[2] as Map<String, dynamic>?;
        _payment = result[3] as Map<String, dynamic>?;
        _errorMessage = null;
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

  Future<void> _openBids() async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => JobBidsPage(jobId: widget.jobId),
      ),
    );
    if (changed == true) await _loadJob();
  }

  Future<void> _openRating() async {
    final bool? reviewed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => JobRatingPage(jobId: widget.jobId),
      ),
    );
    if (reviewed == true) await _loadJob();
  }

  Future<void> _openPayment() async {
    if (_job == null) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => JobPaymentPage(
          jobId: widget.jobId,
          jobTitle: (_job!['title'] ?? 'Pekerjaan').toString(),
        ),
      ),
    );
    if (mounted) await _loadJob();
  }

  Future<void> _openChat() async {
    if (_isOpeningChat) return;
    setState(() => _isOpeningChat = true);
    try {
      final String roomId =
          await _chatService.getOrCreateJobRoom(widget.jobId);
      if (!mounted) return;
      await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(
          builder: (_) => ChatDetailPage(roomId: roomId),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(context, 'Chat belum dapat dibuka: $error');
    } finally {
      if (mounted) setState(() => _isOpeningChat = false);
    }
  }

  Future<void> _confirmCompletion() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi pekerjaan selesai?'),
          content: const Text(
            'Pastikan pekerjaan sudah sesuai. Setelah dikonfirmasi, status akan menjadi selesai.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Periksa Lagi'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: jobGreenColor),
              child: const Text('Konfirmasi Selesai'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    setState(() => _isActionLoading = true);
    try {
      await _jobService.confirmJobCompletion(widget.jobId);
      await _loadJob();
      if (!mounted) return;
      AyoSnackBar.success(context, 'Pekerjaan dikonfirmasi selesai.');
      await _openRating();
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(
        context,
        'Pekerjaan belum dapat dikonfirmasi: $error',
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  bool _hasCancelableMidtransTransaction() {
    final String orderId = (_payment?['order_id'] ?? '').toString().trim();
    final String paymentStatus =
        (_payment?['status'] ?? '').toString().toLowerCase();
    return orderId.isNotEmpty &&
        !<String>['failed', 'expired', 'cancelled', 'refunded']
            .contains(paymentStatus);
  }

  Future<void> _cancelJob() async {
    if (_hasCancelableMidtransTransaction()) {
      await _openPayment();
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Batalkan pekerjaan?'),
          content: const Text(
            'Seluruh penawaran yang masih menunggu akan ikut ditolak.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Kembali'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              child: const Text('Batalkan'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    setState(() => _isActionLoading = true);
    try {
      await _jobService.cancelJob(widget.jobId);
      await _loadJob();
      if (!mounted) return;
      AyoSnackBar.success(context, 'Pekerjaan berhasil dibatalkan.');
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(
        context,
        'Pekerjaan belum dapat dibatalkan: $error',
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
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
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.arrow_back_rounded, color: jobBrownColor),
        ),
        title: const Text(
          'Detail Pekerjaan',
          style: TextStyle(
            color: jobBrownColor,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),

        actions: const <Widget>[HomeShortcutButton()],
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
    if (_errorMessage != null || _job == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.error_outline_rounded,
                size: 50,
                color: jobBrownColor,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Pekerjaan tidak ditemukan.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadJob, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      );
    }

    final Map<String, dynamic> job = _job!;
    final String status = job['status'].toString();
    final String? progressStage = currentJobProgressStage(job);
    final Map<String, dynamic>? latestProgress = latestProgressEntry(
      _timelines,
      jobStatus: status,
      currentStage: progressStage,
    );
    final Map<String, dynamic>? latestEvidence = latestEvidenceEntry(_timelines);
    final List<Map<String, dynamic>> bids = embeddedBids(job);
    final int pendingBidCount =
        bids.where((Map<String, dynamic> bid) => bid['status'] == 'pending').length;
    final bool canManageBids =
        <String>['posted', 'waiting_bid'].contains(status);
    final bool canCancel =
        !<String>['completed', 'cancelled', 'on_progress'].contains(status);
    final bool waitingCompletionConfirmation =
        status == 'on_progress' && progressStage == 'completion_submitted';
    final bool paymentReadyForCompletion =
        hasSelectedPaymentMethod(_payment) && isPaymentPaid(_payment);
    final bool paymentAwaitingCompletion =
        waitingCompletionConfirmation && !paymentReadyForCompletion;
    final bool cashAwaitingPayment =
        paymentAwaitingCompletion && isCashPayment(_payment);
    final bool completedWithoutReview =
        status == 'completed' && _review == null;

    return RefreshIndicator(
      color: jobOrangeColor,
      onRefresh: _loadJob,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: JobStatusChip(status: status),
          ),
          const SizedBox(height: 14),
          _jobHeader(job),
          const SizedBox(height: 14),
          _contentCard(
            title: 'Deskripsi Pekerjaan',
            icon: Icons.description_outlined,
            child: Text(
              (job['description'] ?? 'Tidak ada deskripsi.').toString(),
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF625750),
              ),
            ),
          ),
          if (jobImageUrls(job).isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            _contentCard(
              title: 'Foto Pekerjaan',
              icon: Icons.photo_library_outlined,
              child: NetworkPhotoGallery(urls: jobImageUrls(job)),
            ),
          ],
          const SizedBox(height: 14),
          if (jobNeedsPhysicalLocation(job) && jobLatLng(job) != null) ...<Widget>[
            JobLocationMapCard(job: job),
            const SizedBox(height: 14),
          ],
          if (job['mitra_id'] != null) ...<Widget>[
            _selectedMitraCard(job),
            const SizedBox(height: 10),
            SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _isOpeningChat ? null : _openChat,
                style: OutlinedButton.styleFrom(
                  foregroundColor: jobBrownColor,
                  side: const BorderSide(color: jobOrangeColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(23),
                  ),
                ),
                icon: _isOpeningChat
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: jobBrownColor,
                        ),
                      )
                    : const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text(
                  'Chat dengan Mitra',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (_payment != null &&
              job['mitra_id'] != null &&
              (<String>['accepted', 'on_progress', 'completed'].contains(status) ||
                  <String>['refunded', 'cancelled'].contains(
                    (_payment?['status'] ?? '').toString().toLowerCase(),
                  ))) ...<Widget>[
            JobPaymentStatusCard(
              payment: _payment,
              isCustomer: true,
              onPressed: _openPayment,
            ),
            const SizedBox(height: 14),
          ],
          if (<String>['on_progress', 'completed'].contains(status)) ...<Widget>[
            _progressCard(
              job: job,
              progressStage: progressStage,
              latestProgress: latestProgress,
              latestEvidence: latestEvidence,
            ),
            const SizedBox(height: 14),
          ],
          if (_review != null) ...<Widget>[
            JobReviewCard(review: _review!),
            const SizedBox(height: 14),
          ],
          _contentCard(
            title: 'Rincian Pekerjaan',
            icon: Icons.receipt_long_outlined,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text(
                  'Estimasi harga',
                  style: TextStyle(color: Color(0xFF675B54)),
                ),
                Text(
                  formatRupiah(job['budget']),
                  style: const TextStyle(
                    color: jobBrownColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (waitingCompletionConfirmation) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBCB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.task_alt_rounded, color: jobBrownColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      paymentAwaitingCompletion
                          ? cashAwaitingPayment
                              ? 'Mitra telah mengajukan pekerjaan selesai. Bayarkan nominal tunai yang tertera pada halaman pembayaran sebelum mengonfirmasi pekerjaan.'
                              : 'Mitra telah mengajukan pekerjaan selesai, tetapi pembayaran belum selesai. Pilih atau selesaikan pembayaran terlebih dahulu.'
                          : 'Mitra telah mengajukan pekerjaan selesai. Periksa hasil dan bukti pekerjaan sebelum mengonfirmasi.',
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _isActionLoading
                    ? null
                    : paymentAwaitingCompletion
                        ? _openPayment
                        : _confirmCompletion,
                style: FilledButton.styleFrom(
                  backgroundColor: jobGreenColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                icon: _isActionLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        paymentAwaitingCompletion
                            ? Icons.payments_outlined
                            : Icons.check_circle_outline_rounded,
                      ),
                label: Text(
                  paymentAwaitingCompletion
                      ? cashAwaitingPayment
                          ? 'Bayar Tunai ke Mitra'
                          : 'Selesaikan Pembayaran'
                      : 'Konfirmasi Pekerjaan Selesai',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (completedWithoutReview) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBCB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(Icons.star_outline_rounded, color: jobBrownColor),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bagikan pengalamanmu agar rating mitra dapat diperbarui.',
                      style: TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _isActionLoading ? null : _openRating,
                style: FilledButton.styleFrom(
                  backgroundColor: jobOrangeColor,
                  foregroundColor: const Color(0xFF563700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                icon: const Icon(Icons.star_rounded),
                label: const Text(
                  'Beri Penilaian untuk Mitra',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (canManageBids)
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _isActionLoading ? null : _openBids,
                style: FilledButton.styleFrom(
                  backgroundColor: jobBrownColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                icon: const Icon(Icons.groups_2_outlined),
                label: Text(
                  pendingBidCount == 0
                      ? 'Belum Ada Penawaran'
                      : 'Lihat $pendingBidCount Penawaran',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          if (canManageBids) const SizedBox(height: 10),
          if (canCancel)
            TextButton.icon(
              onPressed: _isActionLoading ? null : _cancelJob,
              icon: const Icon(Icons.cancel_outlined),
              label: Text(
                _hasCancelableMidtransTransaction()
                    ? isPaymentPaid(_payment)
                        ? 'Ajukan Pembatalan & Refund'
                        : 'Batalkan Transaksi & Pekerjaan'
                    : 'Batalkan Pekerjaan',
              ),
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            ),
        ],
      ),
    );
  }

  Widget _jobHeader(Map<String, dynamic> job) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: jobBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      categoryName(job).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: jobBrownColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      job['title'].toString(),
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF292524),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: categoryBackground(categoryName(job)),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  categoryIcon(categoryName(job)),
                  color: jobDarkBrownColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _infoRow(
            Icons.calendar_month_outlined,
            'Waktu Pelaksanaan',
            '${formatJobDate(job['schedule_date'])} · ${formatJobTime(job['schedule_time'])}',
          ),
          const SizedBox(height: 12),
          _infoRow(
            jobWorkModeIcon(jobWorkMode(job)),
            'Cara Pengerjaan',
            jobWorkModeLabel(jobWorkMode(job)),
          ),
          if (jobNeedsPhysicalLocation(job)) ...<Widget>[
            const SizedBox(height: 12),
            _infoRow(Icons.location_on_outlined, 'Lokasi', jobAddress(job)),
          ],
        ],
      ),
    );
  }

  Widget _selectedMitraCard(Map<String, dynamic> job) {
    final dynamic mitra = job['mitra'];
    final String? avatarUrl = mitra is Map ? mitra['avatar_url']?.toString() : null;
    final String? phone = mitra is Map ? mitra['phone']?.toString() : null;
    return _contentCard(
      title: 'Mitra Terpilih',
      icon: Icons.person_outline_rounded,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFFE9CC),
          backgroundImage: _networkImage(avatarUrl),
          child: avatarUrl == null || avatarUrl.isEmpty
              ? const Icon(Icons.person, color: jobBrownColor)
              : null,
        ),
        title: Text(
          selectedMitraName(job),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          phone == null || phone.isEmpty ? 'Mitra Ayo Suruh' : phone,
        ),
      ),
    );
  }

  Widget _progressCard({
    required Map<String, dynamic> job,
    required String? progressStage,
    required Map<String, dynamic>? latestProgress,
    required Map<String, dynamic>? latestEvidence,
  }) {
    final String? evidenceUrl = latestEvidence?['evidence_url']?.toString();
    final String note = (latestProgress?['description'] ?? '').toString();
    return _contentCard(
      title: 'Progres Pekerjaan',
      icon: Icons.timeline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          JobProgressTimeline(
            currentStage: progressStage,
            job: job,
            isCompleted: job['status'] == 'completed',
            compact: true,
          ),
          if (note.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F1F3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                note,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Color(0xFF625750),
                ),
              ),
            ),
          ],
          if (evidenceUrl != null && evidenceUrl.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                evidenceUrl,
                width: double.infinity,
                height: 170,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(
                  height: 120,
                  color: const Color(0xFFF1ECEF),
                  alignment: Alignment.center,
                  child: const Text('Foto bukti belum dapat dimuat.'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  ImageProvider<Object>? _networkImage(dynamic value) {
    final String? url = value?.toString();
    if (url == null || url.isEmpty) return null;
    return NetworkImage(url);
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFF0ECE9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: jobBrownColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF81756E),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _contentCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E9E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: jobBrownColor),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
