import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A read-only star rating display, shared by anywhere a persisted
/// average_rating/rating_count pair is shown (public profiles, bid cards).
/// Shows "New" rather than "0.0★" for a not-yet-rated party — 0 reviews is
/// not the same signal as a genuinely low rating.
class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.rating, required this.count, this.fontSize = 13, this.showCount = true});

  final double? rating;
  final int count;
  final double fontSize;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    if (rating == null || count == 0) {
      return Text('New', style: TextStyle(fontSize: fontSize, color: AppColors.textSecondary));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, size: fontSize + 2, color: Colors.amber),
        const SizedBox(width: 3),
        Text(
          showCount ? '${rating!.toStringAsFixed(1)} ($count)' : rating!.toStringAsFixed(1),
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}
