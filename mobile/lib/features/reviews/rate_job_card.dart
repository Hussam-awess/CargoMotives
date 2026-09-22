import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The non-blocking "Rate your experience" prompt (Phase: ratings) — shown
/// in job/shipment detail whenever `job.reviewable == true`. Deliberately
/// just a card, not a modal: the user can tap it now or leave the job
/// detail screen and rate later, since it stays visible on every future
/// visit until they actually submit a rating (JobResource.reviewable
/// flips to false only once JobReview exists for this viewer).
class RateJobCard extends StatelessWidget {
  const RateJobCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.infoTint,
          border: Border.all(color: const Color(0xFFD6EBFF)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.star_outline, color: Colors.amber, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rate your experience', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text('Let us know how this job went.', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
