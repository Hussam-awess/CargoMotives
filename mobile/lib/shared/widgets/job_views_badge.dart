import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// "N transporters viewed this job" (Cargo Motives Plus benefit) — shown
/// next to a job wherever the customer would look for it (their shipment
/// list, the job detail screen), gated by the *caller* on the viewing
/// customer's own is_featured status, not just on [count] being present:
/// Job.jobViewsCount is a real count for every customer, Plus or not, but
/// only a Plus customer gets to see it.
class JobViewsBadge extends StatelessWidget {
  const JobViewsBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$count transporter${count == 1 ? '' : 's'} viewed this job',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.infoTint,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.visibility_outlined,
              size: 13,
              color: AppColors.ctaBluePressed,
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ctaBluePressed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
