import 'package:flutter/material.dart';

import 'job_helpers.dart';

class JobStatusChip extends StatelessWidget {
  const JobStatusChip({super.key, required this.status});

  final dynamic status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: jobStatusBackground(status),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        jobStatusLabel(status),
        style: TextStyle(
          color: jobStatusForeground(status),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class JobListCard extends StatelessWidget {
  const JobListCard({
    super.key,
    required this.job,
    required this.onTap,
    this.trailingLabel = 'Lihat Detail',
    this.subtitle,
  });

  final Map<String, dynamic> job;
  final VoidCallback onTap;
  final String trailingLabel;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final String category = categoryName(job);
    final String status = (job['status'] ?? '').toString();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: jobCardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: jobBorderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: categoryBackground(category),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      categoryIcon(category),
                      color: jobDarkBrownColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                (job['title'] ?? 'Pekerjaan').toString(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF292422),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            JobStatusChip(status: status),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: Color(0xFF786C65),
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                jobAddress(job),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF786C65),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (subtitle != null) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF685B53),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    formatRupiah(job['budget']),
                    style: const TextStyle(
                      color: jobBrownColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDEECE),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      trailingLabel,
                      style: const TextStyle(
                        color: jobGreenColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyJobState extends StatelessWidget {
  const EmptyJobState({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.work_outline_rounded,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFFFEBD0),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: jobBrownColor),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF312B28),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF756A63),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
