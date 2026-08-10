import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../widgets/ayo_snackbar.dart';
import 'package:image_picker/image_picker.dart';

import 'job_helpers.dart';
import 'job_progress_widgets.dart';
import 'job_service.dart';
import '../widgets/home_shortcut_button.dart';

class UpdateJobStatusPage extends StatefulWidget {
  const UpdateJobStatusPage({super.key, required this.jobId});

  final String jobId;

  @override
  State<UpdateJobStatusPage> createState() => _UpdateJobStatusPageState();
}

class _UpdateJobStatusPageState extends State<UpdateJobStatusPage> {
  final JobService _jobService = JobService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _noteController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  Map<String, dynamic>? _job;
  List<Map<String, dynamic>> _timelines = <Map<String, dynamic>>[];
  XFile? _pickedImage;
  Uint8List? _pickedBytes;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
        _jobService.fetchJob(widget.jobId),
        _jobService.fetchJobTimelines(widget.jobId),
      ]);
      if (!mounted) return;
      setState(() {
        _job = result[0] as Map<String, dynamic>;
        _timelines = result[1] as List<Map<String, dynamic>>;
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

  Future<void> _chooseImageSource() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8D1CD),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Pilih Bukti Pekerjaan',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined, color: jobBrownColor),
                  title: const Text('Ambil dari kamera'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: jobBrownColor),
                  title: const Text('Pilih dari galeri'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (source == null) return;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (image == null) return;
      final Uint8List bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pickedImage = image;
        _pickedBytes = bytes;
      });
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(context, 'Foto belum dapat dipilih: $error');
    }
  }

  Future<void> _updateProgress() async {
    final Map<String, dynamic>? job = _job;
    if (job == null || _isSaving) return;
    final String? currentStage = currentJobProgressStage(job);
    final String? nextStage = nextJobProgressStage(currentStage);
    if (nextStage == null) {
      AyoSnackBar.info(context, 'Seluruh progres sudah diperbarui.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      String? evidenceUrl;
      if (_pickedImage != null && _pickedBytes != null) {
        final String extension = _fileExtension(_pickedImage!.name);
        evidenceUrl = await _jobService.uploadJobEvidence(
          jobId: widget.jobId,
          bytes: _pickedBytes!,
          fileExtension: extension,
          contentType: _contentType(extension),
        );
      }

      await _jobService.advanceJobProgress(
        jobId: widget.jobId,
        progressStage: nextStage,
        note: _noteController.text,
        evidenceUrl: evidenceUrl,
      );
      _noteController.clear();
      if (!mounted) return;
      setState(() {
        _pickedImage = null;
        _pickedBytes = null;
      });
      await _loadData();
      if (!mounted) return;
      AyoSnackBar.success(
        context,
        nextStage == 'completion_submitted'
            ? 'Pekerjaan diajukan selesai. Menunggu konfirmasi customer.'
            : 'Status diperbarui menjadi ${jobProgressLabel(nextStage)}.',
      );
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(
        context,
        'Status belum berhasil diperbarui: $error',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _fileExtension(String fileName) {
    final int dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return 'jpg';
    return fileName.substring(dot + 1).toLowerCase();
  }

  String _contentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
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
          'Update Status Pekerjaan',
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline_rounded, size: 48, color: jobBrownColor),
              const SizedBox(height: 12),
              Text(_errorMessage ?? 'Pekerjaan tidak ditemukan.'),
              const SizedBox(height: 14),
              FilledButton(onPressed: _loadData, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      );
    }

    final Map<String, dynamic> job = _job!;
    final String? currentStage = currentJobProgressStage(job);
    final String? nextStage = nextJobProgressStage(currentStage);
    final Map<String, dynamic>? latest = latestProgressEntry(_timelines);

    return RefreshIndicator(
      color: jobOrangeColor,
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: <Widget>[
          _jobCard(job),
          const SizedBox(height: 24),
          const Text(
            'UPDATE PROGRES',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.4,
              color: Color(0xFF5D4F47),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          JobProgressTimeline(currentStage: currentStage),
          if (nextStage == null) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE2F1D8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(Icons.hourglass_top_rounded, color: jobGreenColor),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pekerjaan sudah diajukan selesai dan sedang menunggu konfirmasi customer.',
                      style: TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          const Text(
            'BUKTI PEKERJAAN (OPSIONAL)',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.3,
              color: Color(0xFF5D4F47),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _evidencePicker(latest, enabled: nextStage != null),
          const SizedBox(height: 14),
          const Text('Catatan Singkat', style: TextStyle(fontSize: 11)),
          const SizedBox(height: 6),
          TextField(
            controller: _noteController,
            maxLines: 3,
            enabled: nextStage != null && !_isSaving,
            decoration: InputDecoration(
              hintText: 'Contoh: Lampu teras dimatikan sesuai permintaan...',
              hintStyle: const TextStyle(color: Color(0xFFB1A6A4), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFFFFBFD),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(0),
                borderSide: const BorderSide(color: Color(0xFF8D7669)),
              ),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF8D7669)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: jobOrangeColor, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: nextStage == null || _isSaving ? null : _updateProgress,
              style: FilledButton.styleFrom(
                backgroundColor: jobOrangeColor,
                disabledBackgroundColor: const Color(0xFFE3DDD9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                elevation: 5,
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sync_rounded),
              label: Text(
                nextStage == null
                    ? 'Menunggu Konfirmasi Customer'
                    : 'Perbarui ke ${jobProgressLabel(nextStage)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _jobCard(Map<String, dynamic> job) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8DDD7)),
      ),
      child: Stack(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDF0CF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Text(
                  'AKTIF',
                  style: TextStyle(fontSize: 10, color: jobGreenColor),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                job['title'].toString(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 7),
              Row(
                children: <Widget>[
                  const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF5E514A)),
                  const SizedBox(width: 4),
                  Text(
                    customerName(job),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF5E514A)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF5E514A)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      jobAddress(job),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF5E514A)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Positioned(
            right: 0,
            top: -4,
            child: Icon(Icons.receipt_long_outlined, size: 54, color: Color(0x1F776B68)),
          ),
        ],
      ),
    );
  }

  Widget _evidencePicker(
    Map<String, dynamic>? latest, {
    required bool enabled,
  }) {
    final String? latestUrl = latest?['evidence_url']?.toString();
    return Row(
      children: <Widget>[
        Expanded(
          child: InkWell(
            onTap: !enabled || _isSaving ? null : _chooseImageSource,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 112,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBFD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE0B889),
                  width: 1.4,
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.add_a_photo_outlined, color: jobBrownColor, size: 28),
                  SizedBox(height: 8),
                  Text('Unggah Foto', style: TextStyle(fontSize: 11, color: jobBrownColor)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            height: 112,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFF1ECEF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _pickedBytes != null
                ? Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Image.memory(_pickedBytes!, fit: BoxFit.contain),
                      Positioned(
                        top: 5,
                        right: 5,
                        child: InkWell(
                          onTap: () => setState(() {
                            _pickedImage = null;
                            _pickedBytes = null;
                          }),
                          child: const CircleAvatar(
                            radius: 11,
                            backgroundColor: Color(0xCC574D43),
                            child: Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  )
                : latestUrl != null && latestUrl.isNotEmpty
                    ? Image.network(
                        latestUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image_outlined,
                          color: jobBrownColor,
                        ),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(Icons.image_outlined, color: Color(0xFF9B918D), size: 30),
                          SizedBox(height: 6),
                          Text(
                            'Belum ada foto',
                            style: TextStyle(fontSize: 10, color: Color(0xFF8A7F79)),
                          ),
                        ],
                      ),
          ),
        ),
      ],
    );
  }
}
