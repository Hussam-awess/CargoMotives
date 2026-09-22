import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A small "verified" indicator for a transporter company's real,
/// admin-reviewed approval (never shown on a customer profile — see
/// CustomerProfileResource's docblock for why a customer has no
/// equivalent real verification signal).
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.verified, size: size, color: AppColors.statusLive);
  }
}
