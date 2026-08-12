import 'package:flutter/material.dart';

import 'job_helpers.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';

class JobReviewCard extends StatelessWidget {
  const JobReviewCard({
    super.key,
    required this.review,
    this.title = 'Penilaian Customer',
  });

  final Map<String, dynamic> review;
  final String title;

  @override
  Widget build(BuildContext context) {
    final int rating = _ratingValue(review['rating']);
    final String comment = (review['review'] ?? '').toString().trim();
    final List<String> tags = _reviewTags(review['tags']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: jobBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.star_rounded, color: jobOrangeColor),
              const SizedBox(width: 8),
              Expanded(
                child: AyoText(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              AyoText(
                '$rating/5',
                style: TextStyle(
                  color: jobBrownColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StarRatingDisplay(rating: rating),
          if (tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: tags.map((String tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1DE),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFF3D5AE)),
                  ),
                  child: AyoText(
                    tag,
                    style: TextStyle(
                      color: jobDarkBrownColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (comment.isNotEmpty) ...<Widget>[
            const SizedBox(height: 13),
            AyoText(
              comment,
              style: const TextStyle(
                color: Color(0xFF665A53),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StarRatingDisplay extends StatelessWidget {
  const StarRatingDisplay({
    super.key,
    required this.rating,
    this.size = 24,
  });

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(5, (int index) {
        return Icon(
          index < rating ? Icons.star_rounded : Icons.star_border_rounded,
          color: jobOrangeColor,
          size: size,
        );
      }),
    );
  }
}

int _ratingValue(dynamic value) {
  if (value is int) return value.clamp(0, 5).toInt();
  if (value is num) return value.round().clamp(0, 5).toInt();
  return int.tryParse(value?.toString() ?? '')?.clamp(0, 5).toInt() ?? 0;
}

List<String> _reviewTags(dynamic value) {
  if (value is List) {
    return value
        .map((dynamic item) => item.toString().trim())
        .where((String item) => item.isNotEmpty)
        .toList();
  }
  return <String>[];
}
