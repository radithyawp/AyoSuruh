import 'package:flutter/material.dart';

import 'job_helpers.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';

class JobProgressTimeline extends StatelessWidget {
  const JobProgressTimeline({
    super.key,
    required this.currentStage,
    this.job,
    this.isCompleted = false,
    this.compact = false,
  });

  final String? currentStage;
  final Map<String, dynamic>? job;
  final bool isCompleted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? jobData = job;
    final List<String> stages = jobData == null
        ? jobProgressStages
        : jobProgressStagesFor(jobData);
    final int currentIndex = isCompleted
        ? stages.length - 1
        : jobData == null
            ? jobProgressIndex(currentStage)
            : jobProgressIndexFor(jobData, currentStage);

    return Column(
      children: List<Widget>.generate(stages.length, (int index) {
        final String stage = stages[index];
        final bool completed = isCompleted || index < currentIndex;
        final bool active = !isCompleted && index == currentIndex;
        final bool next = !isCompleted && index == currentIndex + 1;
        final bool showLine = index < stages.length - 1;

        return _ProgressStep(
          stage: stage,
          completed: completed,
          active: active,
          next: next,
          showLine: showLine,
          compact: compact,
          job: jobData,
        );
      }),
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
    required this.stage,
    required this.completed,
    required this.active,
    required this.next,
    required this.showLine,
    required this.compact,
    this.job,
  });

  final String stage;
  final bool completed;
  final bool active;
  final bool next;
  final bool showLine;
  final bool compact;
  final Map<String, dynamic>? job;

  @override
  Widget build(BuildContext context) {
    final Color circleColor = completed
        ? const Color(0xFFD8EDC8)
        : active
            ? jobOrangeColor
            : next
                ? const Color(0xFFFFB33A)
                : const Color(0xFFE7E3E7);
    final Color iconColor = completed
        ? jobGreenColor
        : active || next
            ? jobDarkBrownColor
            : const Color(0xFF777176);
    final double circleSize = compact ? 32 : 40;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: circleSize,
          child: Column(
            children: <Widget>[
              Container(
                width: circleSize,
                height: circleSize,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                  border: active
                      ? Border.all(color: Theme.of(context).colorScheme.surface, width: 3)
                      : null,
                  boxShadow: active
                      ? const <BoxShadow>[
                          BoxShadow(
                            color: jobOrangeColor,
                            spreadRadius: 2,
                            blurRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  completed ? Icons.check_rounded : jobProgressIcon(stage),
                  size: compact ? 18 : 22,
                  color: iconColor,
                ),
              ),
              if (showLine)
                Container(
                  width: 2,
                  height: compact ? 24 : 30,
                  color: completed || active
                      ? jobOrangeColor
                      : const Color(0xFFE3DEE1),
                ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: compact ? 4 : 5, bottom: compact ? 17 : 21),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AyoText(
                  job == null
                      ? jobProgressLabel(stage)
                      : jobProgressLabelFor(job!, stage),
                  style: TextStyle(
                    fontSize: compact ? 13 : 15,
                    fontWeight: active || next || completed
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: const Color(0xFF564A43),
                  ),
                ),
                if (!compact) ...<Widget>[
                  const SizedBox(height: 2),
                  AyoText(
                    job == null
                        ? jobProgressDescription(stage)
                        : jobProgressDescriptionFor(job!, stage),
                    style: const TextStyle(
                      fontSize: 10,
                      height: 1.35,
                      color: Color(0xFF62564F),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Map<String, dynamic>? latestProgressEntry(
  List<Map<String, dynamic>> timelines, {
  String? jobStatus,
  String? currentStage,
}) {
  final List<Map<String, dynamic>> ordered = _newestTimelineFirst(timelines);

  // Saat pekerjaan telah selesai, prioritaskan timeline konfirmasi customer.
  // Ini mencegah catatan tahap lama (misalnya "Menuju Lokasi") tetap tampil
  // walaupun jobs.status sudah completed.
  if (jobStatus == 'completed') {
    for (final Map<String, dynamic> row in ordered) {
      if (row['status']?.toString() == 'completed') return row;
    }
  }

  // Untuk pekerjaan yang masih berjalan, ambil catatan yang benar-benar
  // sesuai dengan progress_stage terbaru pada tabel jobs.
  if (currentStage != null && currentStage.isNotEmpty) {
    for (final Map<String, dynamic> row in ordered) {
      if (row['progress_stage']?.toString() == currentStage) return row;
    }
  }

  for (final Map<String, dynamic> row in ordered) {
    final String? stage = row['progress_stage']?.toString();
    if (stage != null && stage.isNotEmpty) return row;
  }
  return null;
}

Map<String, dynamic>? latestEvidenceEntry(
  List<Map<String, dynamic>> timelines,
) {
  for (final Map<String, dynamic> row in _newestTimelineFirst(timelines)) {
    final String? url = row['evidence_url']?.toString();
    if (url != null && url.isNotEmpty) return row;
  }
  return null;
}

List<Map<String, dynamic>> _newestTimelineFirst(
  List<Map<String, dynamic>> timelines,
) {
  final List<Map<String, dynamic>> ordered =
      List<Map<String, dynamic>>.from(timelines);
  ordered.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
    final DateTime? aTime = DateTime.tryParse(a['created_at']?.toString() ?? '');
    final DateTime? bTime = DateTime.tryParse(b['created_at']?.toString() ?? '');
    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    return bTime.compareTo(aTime);
  });
  return ordered;
}
