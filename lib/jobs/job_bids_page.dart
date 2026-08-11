import 'package:flutter/material.dart';
import '../widgets/ayo_snackbar.dart';

import 'job_helpers.dart';
import 'job_service.dart';
import 'job_widgets.dart';
import '../widgets/home_shortcut_button.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';

class JobBidsPage extends StatefulWidget {
  const JobBidsPage({super.key, required this.jobId});

  final String jobId;

  @override
  State<JobBidsPage> createState() => _JobBidsPageState();
}

class _JobBidsPageState extends State<JobBidsPage> {
  final JobService _jobService = JobService();
  bool _isLoading = true;
  String? _processingBidId;
  Map<String, dynamic>? _job;
  List<Map<String, dynamic>> _bids = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
        _jobService.fetchJob(widget.jobId),
        _jobService.fetchJobBids(widget.jobId),
      ]);
      if (!mounted) return;
      setState(() {
        _job = result[0] as Map<String, dynamic>;
        _bids = result[1] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AyoSnackBar.error(context, 'Penawaran belum dapat dimuat: $error');
    }
  }

  Future<void> _acceptBid(Map<String, dynamic> bid) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const AyoText('Terima penawaran ini?'),
          content: AyoText(
            'Mitra ${_mitraName(bid)} akan dipilih. Penawaran mitra lain otomatis ditolak.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AyoText('Kembali'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: jobOrangeColor),
              child: const AyoText('Terima'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    final String bidId = bid['id'].toString();
    setState(() => _processingBidId = bidId);
    try {
      await _jobService.acceptBid(jobId: widget.jobId, bidId: bidId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            icon: Icon(Icons.check_circle_rounded, color: jobGreenColor, size: 52),
            title: const AyoText('Mitra berhasil dipilih'),
            content: AyoText(
              '${_mitraName(bid)} sekarang menjadi mitra untuk pekerjaan ini.',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: <Widget>[
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const AyoText('Selesai'),
              ),
            ],
          );
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(
        context,
        'Penawaran belum dapat diterima: $error',
      );
    } finally {
      if (mounted) setState(() => _processingBidId = null);
    }
  }

  Future<void> _rejectBid(Map<String, dynamic> bid) async {
    final String bidId = bid['id'].toString();
    setState(() => _processingBidId = bidId);
    try {
      await _jobService.rejectBid(bidId);
      await _loadData();
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(context, 'Penawaran belum dapat ditolak: $error');
    } finally {
      if (mounted) setState(() => _processingBidId = null);
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
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: jobBrownColor),
        ),
        title: AyoText(
          'Penawaran Mitra',
          style: TextStyle(
            color: jobBrownColor,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),

        actions: const <Widget>[HomeShortcutButton()],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: jobOrangeColor))
          : RefreshIndicator(
              color: jobOrangeColor,
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: <Widget>[
                  if (_job != null) _buildJobSummary(_job!),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const AyoText(
                        'Pilih Penawaran',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      AyoText(
                        '${_bids.where((bid) => bid['status'] == 'pending').length} Mitra Menunggu',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF70645D)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_bids.isEmpty)
                    const EmptyJobState(
                      title: 'Belum ada penawaran',
                      description: 'Penawaran dari mitra akan muncul pada halaman ini.',
                      icon: Icons.groups_2_outlined,
                    )
                  else
                    ..._bids.map(_buildBidCard),
                ],
              ),
            ),
    );
  }

  Widget _buildJobSummary(Map<String, dynamic> job) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD9B0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AyoText(
            'PEKERJAAN AKTIF',
            style: TextStyle(fontSize: 9, color: jobDarkBrownColor, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          AyoText(
            job['title'].toString(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          AyoText(
            '${formatJobDate(job['schedule_date'])}, ${formatJobTime(job['schedule_time'])}',
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 3),
          AyoText(jobAddress(job), style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 3),
          AyoText(
            'Harga awal: ${formatRupiah(job['budget'])}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildBidCard(Map<String, dynamic> bid) {
    final bool processing = _processingBidId == bid['id'].toString();
    final String status = bid['status'].toString();
    final num rating = _mitraRating(bid);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: status == 'accepted' ? const Color(0xFFE6F2DD) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'accepted' ? const Color(0xFFA9C795) : jobBorderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFFFE6C7),
                backgroundImage: _mitraAvatar(bid) == null
                    ? null
                    : NetworkImage(_mitraAvatar(bid)!),
                child: _mitraAvatar(bid) == null
                    ? Icon(Icons.person, color: jobBrownColor)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AyoText(
                      _mitraName(bid),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    Row(
                      children: <Widget>[
                        const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                        AyoText(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 6),
                        AyoText(
                          bidStatusLabel(status),
                          style: TextStyle(
                            fontSize: 10,
                            color: status == 'rejected'
                                ? Colors.red.shade700
                                : jobGreenColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AyoText(
                formatRupiah(bid['price']),
                style: TextStyle(
                  color: jobBrownColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildMitraLocationInfo(bid),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F2F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: AyoText(
              '“${(bid['message'] ?? 'Tidak ada pesan.').toString()}”',
              style: const TextStyle(fontSize: 11, height: 1.4, color: Color(0xFF5F535A)),
            ),
          ),
          if ((bid['estimated_time'] ?? '').toString().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            AyoText(
              'Estimasi: ${bid['estimated_time']}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6A5D55)),
            ),
          ],
          if (status == 'pending') ...<Widget>[
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: processing ? null : () => _rejectBid(bid),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: jobDarkBrownColor,
                      side: BorderSide(color: jobBorderColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    ),
                    child: const AyoText('Tolak'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: processing ? null : () => _acceptBid(bid),
                    style: FilledButton.styleFrom(
                      backgroundColor: jobOrangeColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    ),
                    child: processing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const AyoText('Terima'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMitraLocationInfo(Map<String, dynamic> bid) {
    final String area = _mitraArea(bid);
    final String distance = _mitraDistanceLabel(bid);
    final bool hasArea = area.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFDFC0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.location_on_outlined,
            size: 18,
            color: jobOrangeColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AyoText(
                  hasArea ? area : 'Area Mitra belum tersedia',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: jobDarkBrownColor,
                  ),
                ),
                const SizedBox(height: 2),
                AyoText(
                  distance,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.3,
                    color: Color(0xFF74675F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _mitraArea(Map<String, dynamic> bid) {
    return (bid['mitra_area'] ?? '').toString().trim();
  }

  String _mitraDistanceLabel(Map<String, dynamic> bid) {
    final dynamic rawDistance = bid['distance_km'];
    final double? distanceKm = rawDistance is num
        ? rawDistance.toDouble()
        : double.tryParse(rawDistance?.toString() ?? '');

    if (distanceKm == null || distanceKm.isNaN || distanceKm.isInfinite) {
      return 'Jarak dari lokasi pekerjaan belum tersedia';
    }

    if (distanceKm < 1) {
      final int meters = (distanceKm * 1000).round();
      return '± $meters m dari lokasi pekerjaan';
    }

    final String value = distanceKm < 10
        ? distanceKm.toStringAsFixed(1)
        : distanceKm.toStringAsFixed(0);
    return '± $value km dari lokasi pekerjaan';
  }

  String _mitraName(Map<String, dynamic> bid) {
    final dynamic mitra = bid['mitra'];
    if (mitra is Map) {
      final dynamic user = mitra['user'];
      if (user is Map && user['fullname'] != null) {
        return user['fullname'].toString();
      }
    }
    return 'Mitra Ayo Suruh';
  }

  String? _mitraAvatar(Map<String, dynamic> bid) {
    final dynamic mitra = bid['mitra'];
    if (mitra is Map) {
      final dynamic user = mitra['user'];
      if (user is Map && user['avatar_url'] != null) {
        return user['avatar_url'].toString();
      }
    }
    return null;
  }

  num _mitraRating(Map<String, dynamic> bid) {
    final dynamic mitra = bid['mitra'];
    if (mitra is Map) {
      final dynamic rating = mitra['rating'];
      if (rating is num) return rating;
      return num.tryParse(rating?.toString() ?? '') ?? 0;
    }
    return 0;
  }
}
