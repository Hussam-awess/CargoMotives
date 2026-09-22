import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Cargo Motives Plus status, shown wherever a Plus customer or company is
/// identified to someone else — their public profile, their bids (the
/// existing plain "FEATURED" text on a bid card is the same signal, just
/// styled inline there instead of as a standalone pill). Distinct from
/// [VerifiedBadge]: Plus is a paid tier, not an admin-reviewed approval.
class PlusBadge extends StatelessWidget {
  const PlusBadge({super.key, this.compact = false});

  /// A smaller, icon-only rendering for tight spaces (e.g. next to a name
  /// in a list row) — the full pill with "PLUS" text is the default.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Icon(Icons.bolt, size: 15, color: AppColors.accent);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 12, color: AppColors.accent),
          const SizedBox(width: 3),
          Text(
            'PLUS',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
