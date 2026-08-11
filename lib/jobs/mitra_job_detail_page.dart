import 'package:flutter/material.dart';

import '../chats/chat_detail_page.dart';
import '../chats/chat_service.dart';
import '../notifications/notification_service.dart';
import '../location/job_location_map.dart';
import '../payments/job_payment_widgets.dart';
import '../payments/payment_helpers.dart';
import '../payments/payment_service.dart';
import 'job_helpers.dart';
import 'job_progress_widgets.dart';
import 'job_review_widgets.dart';
import 'job_service.dart';
import 'job_widgets.dart';
import 'submit_bid_page.dart';
import 'update_job_status_page.dart';
import '../widgets/home_shortcut_button.dart';
import '../widgets/network_photo_gallery.dart';

class MitraJobDetailPage extends StatefulWidget {
  const MitraJobDetailPage({super.key, required this.jobId});

  final String jobId;

  @override
  State<MitraJobDetailPage> createState() => _MitraJobDetailPageState();
}

class _MitraJobDetailPageState extends State<MitraJobDetailPage> {
  final JobService _jobService = JobService();
  final ChatService _chatService = ChatService();
  final NotificationService _notificationService = NotificationService();
  final PaymentService _paymentService = PaymentService();
  bool _isLoading = true;
  bool _isStarting = false;
  bool _isOpeningChat = false;
  Map<String, dynamic>? _job;
  Map<String, dynamic>? _myBid;
  Map<String, dynamic>? _review;
  Map<String, dynamic>? _jobAccess;
  Map<String, dynamic>? _payment;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      await _notificationService.markJobNotificationsRead(widget.jobId);
      final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
        _jobService.fetchJob(widget.jobId),
        _jobService.fetchMyBidForJob(widget.jobId),
        _jobService.fetchJobReview(widget.jobId),
        _jobService.fetchMyJobAccess(widget.jobId),
      ]);
      final Map<String, dynamic> loadedJob =
          result[0] as Map<String, dynamic>;
      final Map<String, dynamic>? loadedBid =
          result[1] as Map<String, dynamic>?;
      final Map<String, dynamic>? loadedAccess =
          result[3] as Map<String, dynamic>?;
      final bool selectedMitra =
          (loadedJob['mitra_id'] ?? '').toString() == _jobService.currentUserId ||
          loadedAccess?['is_selected_mitra'] == true ||
          (loadedAccess?['my_bid_status'] ?? loadedBid?['status'])?.toString() ==
              'accepted';
      final Map<String, dynamic>? loadedPayment = selectedMitra
          ? await _paymentService.fetchJobPayment(widget.jobId)
          : null;

      if (!mounted) return;
      setState(() {
        _job = loadedJob;
        _myBid = loadedBid;
        _review = result[2] as Map<String, dynamic>?;
        _jobAccess = loadedAccess;
        _payment = loadedPayment;
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

  Future<void> _submitBid() async {
    if (_job == null) return;
    final String customerId = (_job!['customer_id'] ?? '').toString().trim();
    final String currentUserId = _jobService.currentUserId.trim();
    if (customerId.isNotEmpty &&
        customerId.toLowerCase() == currentUserId.toLowerCase()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pekerjaan ini dibuat oleh akunmu sendiri. Buka dari mode Customer untuk melihat penawaran.',
          ),
          backgroundColor: jobBrownColor,
        ),
      );
      return;
    }
    final bool? submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => SubmitBidPage(
          jobId: widget.jobId,
          jobTitle: _job!['title'].toString(),
          initialBudget: _job!['budget'],
        ),
      ),
    );
    if (submitted == true) await _loadData();
  }

  Future<void> _openProgress() async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => UpdateJobStatusPage(jobId: widget.jobId),
      ),
    );
    if (changed == true) await _loadData();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chat belum dapat dibuka: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isOpeningChat = false);
    }
  }

  Future<void> _startJob() async {
    setState(() => _isStarting = true);
    try {
      await _jobService.startJob(widget.jobId);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pekerjaan dimulai. Status berubah menjadi Sedang Dikerjakan.'),
          backgroundColor: jobGreenColor,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pekerjaan belum dapat dimulai: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isStarting = false);
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
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),

        actions: const <Widget>[HomeShortcutButton()],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: jobOrangeColor));
    }
    if (_errorMessage != null || _job == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorMessage ?? 'Pekerjaan tidak ditemukan.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final Map<String, dynamic> job = _job!;
    final String status = job['status'].toString();
    final bool available = <String>['posted', 'waiting_bid'].contains(status);
    final String selectedMitraId = (job['mitra_id'] ?? '').toString().trim();
    final String currentMitraId = _jobService.currentUserId.trim();
    final bool assignedFromJob = selectedMitraId.isNotEmpty &&
        selectedMitraId.toLowerCase() == currentMitraId.toLowerCase();
    final bool assignedFromAccess = _jobAccess?['is_selected_mitra'] == true;
    final bool assignedFromAcceptedBid =
        (_jobAccess?['my_bid_status'] ?? _myBid?['status'])?.toString() == 'accepted';
    final bool assignedToMe =
        assignedFromJob || assignedFromAccess || assignedFromAcceptedBid;
    final String customerId = (job['customer_id'] ?? '').toString().trim();
    final bool isOwnCustomerJob = customerId.isNotEmpty &&
        customerId.toLowerCase() == currentMitraId.toLowerCase();
    final bool paymentAllowsStart = canMitraStartJob(_payment);

    return RefreshIndicator(
      color: jobOrangeColor,
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              JobStatusChip(status: status),
              Text(
                formatJobDateTime(job['created_at']),
                style: const TextStyle(fontSize: 10, color: Color(0xFF7B7069)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
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
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: categoryBackground(categoryName(job)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        categoryIcon(categoryName(job)),
                        color: jobDarkBrownColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            categoryName(job).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: jobBrownColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            job['title'].toString(),
                            style: const TextStyle(
                              fontSize: 21,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _info(Icons.person_outline_rounded, 'Customer', customerName(job)),
                const SizedBox(height: 10),
                _info(
                  jobWorkModeIcon(jobWorkMode(job)),
                  'Cara Pengerjaan',
                  jobWorkModeLabel(jobWorkMode(job)),
                ),
                if (jobNeedsPhysicalLocation(job)) ...<Widget>[
                  const SizedBox(height: 10),
                  _info(Icons.location_on_outlined, 'Lokasi', jobAddress(job)),
                ],
                const SizedBox(height: 10),
                _info(
                  Icons.calendar_month_outlined,
                  'Jadwal',
                  '${formatJobDate(job['schedule_date'])} · ${formatJobTime(job['schedule_time'])}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (jobNeedsPhysicalLocation(job) && jobLatLng(job) != null) ...<Widget>[
            JobLocationMapCard(job: job),
            const SizedBox(height: 14),
          ],
          _card(
            title: 'Deskripsi Pekerjaan',
            child: Text(
              (job['description'] ?? 'Tidak ada deskripsi.').toString(),
              style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF625750)),
            ),
          ),
          if (jobImageUrls(job).isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            _card(
              title: 'Foto dari Customer',
              child: NetworkPhotoGallery(urls: jobImageUrls(job)),
            ),
          ],
          const SizedBox(height: 14),
          _card(
            title: 'Budget Customer',
            child: Text(
              formatRupiah(job['budget']),
              style: const TextStyle(
                color: jobBrownColor,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (_myBid != null) ...<Widget>[
            const SizedBox(height: 14),
            _buildMyBid(_myBid!),
          ],
          if (assignedToMe &&
              _payment != null &&
              (<String>['accepted', 'on_progress', 'completed'].contains(status) ||
                  <String>['refunded', 'cancelled'].contains(
                    (_payment?['status'] ?? '').toString().toLowerCase(),
                  ))) ...<Widget>[
            const SizedBox(height: 14),
            JobPaymentStatusCard(
              payment: _payment,
              isCustomer: false,
            ),
          ],
          if (assignedToMe && status == 'on_progress') ...<Widget>[
            const SizedBox(height: 14),
            _card(
              title: 'Progres Pekerjaan',
              child: JobProgressTimeline(
                currentStage: currentJobProgressStage(job),
                job: job,
                compact: true,
              ),
            ),
          ],
          if (assignedToMe && status == 'completed' && _review != null) ...<Widget>[
            const SizedBox(height: 14),
            JobReviewCard(review: _review!),
          ],
          const SizedBox(height: 22),
          if (assignedToMe) ...<Widget>[
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _isOpeningChat ? null : _openChat,
                style: OutlinedButton.styleFrom(
                  foregroundColor: jobBrownColor,
                  side: const BorderSide(color: jobOrangeColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
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
                  'Chat dengan Customer',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (isOwnCustomerJob) ...<Widget>[
            _card(
              title: 'Pekerjaan Milik Akunmu',
              child: const Text(
                'Pekerjaan ini kamu buat sebagai Customer. Kembali ke mode Customer untuk melihat dan memilih penawaran Mitra.',
                style: TextStyle(fontSize: 12.5, height: 1.45),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (available && _myBid == null && !isOwnCustomerJob)
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _submitBid,
                style: FilledButton.styleFrom(
                  backgroundColor: jobOrangeColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
                icon: const Icon(Icons.send_rounded),
                label: const Text(
                  'Ajukan Penawaran',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          if (assignedToMe && status == 'accepted')
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _isStarting || !paymentAllowsStart ? null : _startJob,
                style: FilledButton.styleFrom(
                  backgroundColor: jobBrownColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
                icon: _isStarting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(
                  paymentAllowsStart
                      ? 'Mulai Pekerjaan'
                      : mitraPaymentGateLabel(_payment),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          if (assignedToMe && status == 'on_progress')
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: paymentAllowsStart ? _openProgress : null,
                style: FilledButton.styleFrom(
                  backgroundColor: jobOrangeColor,
                  disabledBackgroundColor: const Color(0xFFE3DDD9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
                icon: Icon(
                  paymentAllowsStart
                      ? Icons.sync_rounded
                      : Icons.lock_outline_rounded,
                ),
                label: Text(
                  paymentAllowsStart
                      ? 'Update Status Pekerjaan'
                      : mitraPaymentGateLabel(_payment),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          if (!available && !assignedToMe && _myBid == null)
            const EmptyJobState(
              title: 'Mitra lain telah dipilih',
              description:
                  'Customer telah memilih mitra lain untuk mengerjakan pekerjaan ini.',
              icon: Icons.lock_clock_outlined,
            ),
        ],
      ),
    );
  }

  Widget _buildMyBid(Map<String, dynamic> bid) {
    final String status = bid['status'].toString();
    final Color background = status == 'accepted'
        ? const Color(0xFFE2F1D8)
        : status == 'rejected'
            ? const Color(0xFFFFE0DD)
            : const Color(0xFFFFEBCD);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text('Penawaran Saya', style: TextStyle(fontWeight: FontWeight.w800)),
              Text(
                bidStatusLabel(status),
                style: TextStyle(
                  color: status == 'rejected' ? Colors.red.shade700 : jobGreenColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatRupiah(bid['price']),
            style: const TextStyle(fontSize: 20, color: jobBrownColor, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Estimasi: ${bid['estimated_time'] ?? '-'}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            (bid['message'] ?? '').toString(),
            style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF5F554E)),
          ),
        ],
      ),
    );
  }

  Widget _info(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: jobBrownColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF7B706A))),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card({required String title, required Widget child}) {
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
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
