import 'package:flutter/material.dart';
import '../widgets/ayo_snackbar.dart';

import 'job_helpers.dart';
import 'job_review_widgets.dart';
import 'job_service.dart';
import '../widgets/home_shortcut_button.dart';

class JobRatingPage extends StatefulWidget {
  const JobRatingPage({super.key, required this.jobId});

  final String jobId;

  @override
  State<JobRatingPage> createState() => _JobRatingPageState();
}

class _JobRatingPageState extends State<JobRatingPage> {
  static const Map<String, List<String>> _categoryTags = <String, List<String>>{
    'design & coding': <String>[
      'Sesuai Brief',
      'Kualitas Hasil',
      'Tepat Waktu',
      'Komunikatif',
      'Responsif Revisi',
    ],
    'elektronik': <String>[
      'Diagnosis Tepat',
      'Berfungsi Baik',
      'Rapi',
      'Cepat',
      'Komunikatif',
    ],
    'antar-jemput': <String>[
      'Tepat Waktu',
      'Aman',
      'Ramah',
      'Nyaman',
      'Komunikatif',
    ],
    'jasa titip': <String>[
      'Sesuai Pesanan',
      'Transparan',
      'Cepat',
      'Aman',
      'Responsif',
    ],
    'survey & informasi kost': <String>[
      'Informasi Akurat',
      'Detail',
      'Foto Jelas',
      'Cepat',
      'Komunikatif',
    ],
    'administrasi': <String>[
      'Teliti',
      'Rapi',
      'Tepat Waktu',
      'Jelas',
      'Responsif',
    ],
    'rumah tangga': <String>[
      'Bersih',
      'Rapi',
      'Teliti',
      'Cepat',
      'Ramah',
    ],
    'otomotif': <String>[
      'Diagnosis Tepat',
      'Aman',
      'Rapi',
      'Solutif',
      'Cepat',
    ],
  };

  static const List<String> _defaultTags = <String>[
    'Sesuai Permintaan',
    'Profesional',
    'Tepat Waktu',
    'Komunikatif',
    'Hasil Memuaskan',
  ];

  final JobService _jobService = JobService();
  final TextEditingController _reviewController = TextEditingController();

  Map<String, dynamic>? _job;
  Map<String, dynamic>? _existingReview;
  final Set<String> _selectedTags = <String>{};
  int _rating = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
        _jobService.fetchJob(widget.jobId),
        _jobService.fetchJobReview(widget.jobId),
      ]);
      if (!mounted) return;
      final Map<String, dynamic>? existing =
          result[1] as Map<String, dynamic>?;
      setState(() {
        _job = result[0] as Map<String, dynamic>;
        _existingReview = existing;
        if (existing != null) {
          _rating = _parseRating(existing['rating']);
          _reviewController.text = (existing['review'] ?? '').toString();
          final dynamic tags = existing['tags'];
          if (tags is List) {
            _selectedTags
              ..clear()
              ..addAll(tags.map((dynamic item) => item.toString()));
          }
        }
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  List<String> get _availableTags {
    final Map<String, dynamic>? job = _job;
    if (job == null) return _defaultTags;
    final String category = categoryName(job).trim().toLowerCase();
    return _categoryTags[category] ?? _defaultTags;
  }

  int _parseRating(dynamic value) {
    if (value is int) return value.clamp(0, 5).toInt();
    if (value is num) return value.round().clamp(0, 5).toInt();
    return int.tryParse(value?.toString() ?? '')?.clamp(0, 5).toInt() ?? 0;
  }

  Future<void> _submit() async {
    if (_rating < 1) {
      AyoSnackBar.info(context, 'Pilih rating bintang terlebih dahulu.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _jobService.submitJobReview(
        jobId: widget.jobId,
        rating: _rating,
        review: _reviewController.text,
        tags: _selectedTags.toList(),
      );
      if (!mounted) return;
      AyoSnackBar.success(
        context,
        'Terima kasih, penilaian berhasil dikirim.',
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(
        context,
        'Penilaian belum berhasil dikirim: $error',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
          icon: const Icon(Icons.arrow_back_rounded, color: jobBrownColor),
        ),
        title: const Text(
          'Beri Penilaian',
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
                color: jobBrownColor,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Data pekerjaan tidak ditemukan.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton(onPressed: _loadData, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      );
    }

    final Map<String, dynamic> job = _job!;
    if (_existingReview != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
        children: <Widget>[
          _jobSummary(job),
          const SizedBox(height: 18),
          _mitraHeader(job),
          const SizedBox(height: 18),
          JobReviewCard(
            review: _existingReview!,
            title: 'Penilaian Sudah Dikirim',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
      children: <Widget>[
        _jobSummary(job),
        const SizedBox(height: 22),
        _mitraHeader(job),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF0E8E2)),
          ),
          child: Column(
            children: <Widget>[
              const Text(
                'Bagaimana hasil pekerjaannya?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(5, (int index) {
                  final int value = index + 1;
                  return IconButton(
                    onPressed: () => setState(() => _rating = value),
                    iconSize: 38,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      value <= _rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: jobOrangeColor,
                    ),
                  );
                }),
              ),
              if (_rating > 0)
                Text(
                  _ratingLabel(_rating),
                  style: const TextStyle(
                    color: jobBrownColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Apa yang kamu sukai?',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableTags.map((String tag) {
            final bool selected = _selectedTags.contains(tag);
            return FilterChip(
              selected: selected,
              showCheckmark: false,
              label: Text(tag),
              avatar: Icon(
                _tagIcon(tag),
                size: 16,
                color: selected ? jobDarkBrownColor : const Color(0xFF776A62),
              ),
              onSelected: (bool value) {
                setState(() {
                  if (value) {
                    _selectedTags.add(tag);
                  } else {
                    _selectedTags.remove(tag);
                  }
                });
              },
              selectedColor: const Color(0xFFFFE4BE),
              backgroundColor: Colors.white,
              side: BorderSide(
                color: selected ? jobOrangeColor : const Color(0xFFE5D7CB),
              ),
              labelStyle: const TextStyle(fontSize: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        const Text(
          'Ceritakan pengalamanmu',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _reviewController,
          minLines: 4,
          maxLines: 6,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: 'Tuliskan ulasan detail tentang layanan mitra...',
            hintStyle: const TextStyle(fontSize: 12),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Color(0xFFF0E8E2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: jobOrangeColor),
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: jobOrangeColor,
              foregroundColor: const Color(0xFF563700),
              disabledBackgroundColor: const Color(0xFFFFD39B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Kirim Penilaian',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _jobSummary(Map<String, dynamic> job) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F2EE),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFECE1D9)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: categoryBackground(categoryName(job)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              categoryIcon(categoryName(job)),
              color: jobDarkBrownColor,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Selesai',
                  style: TextStyle(
                    color: jobGreenColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  job['title'].toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatJobDate(job['schedule_date'])} · ${formatJobTime(job['schedule_time'])}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF746962),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mitraHeader(Map<String, dynamic> job) {
    final dynamic mitra = job['mitra'];
    final String name = selectedMitraName(job);
    final String? avatarUrl = mitra is Map && mitra['avatar_url'] != null
        ? mitra['avatar_url'].toString()
        : null;

    return Column(
      children: <Widget>[
        CircleAvatar(
          radius: 45,
          backgroundColor: const Color(0xFFFFE4C5),
          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
              ? NetworkImage(avatarUrl)
              : null,
          child: avatarUrl == null || avatarUrl.isEmpty
              ? const Icon(Icons.person_rounded, size: 46, color: jobBrownColor)
              : null,
        ),
        const SizedBox(height: 10),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(
          'Mitra ${categoryName(job)}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF776B64)),
        ),
      ],
    );
  }

  String _ratingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Kurang Memuaskan';
      case 2:
        return 'Cukup';
      case 3:
        return 'Baik';
      case 4:
        return 'Sangat Baik';
      case 5:
        return 'Luar Biasa';
      default:
        return '';
    }
  }

  IconData _tagIcon(String tag) {
    final String value = tag.toLowerCase();
    if (value.contains('waktu') || value.contains('cepat')) {
      return Icons.schedule_rounded;
    }
    if (value.contains('ramah') || value.contains('komunikatif') || value.contains('responsif')) {
      return Icons.sentiment_satisfied_alt_rounded;
    }
    if (value.contains('bersih') || value.contains('rapi')) {
      return Icons.auto_awesome_rounded;
    }
    if (value.contains('aman')) return Icons.verified_user_outlined;
    if (value.contains('foto')) return Icons.photo_camera_outlined;
    if (value.contains('diagnosis') || value.contains('solutif')) {
      return Icons.build_circle_outlined;
    }
    return Icons.check_circle_outline_rounded;
  }
}
