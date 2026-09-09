import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Human-readable label + color for a [Job.status] value, shared by every
/// screen that renders a status pill (Customer and Transporter alike) so
/// the wording and colors stay consistent across the app.
String jobStatusLabel(String status) => switch (status) {
  'open' => 'Open for bids',
  'assigned' => 'Assigned',
  'en_route_pickup' => 'En route to pickup',
  'picked_up' => 'Picked up',
  'in_transit' => 'In Transit',
  'delivered' => 'Delivered',
  'completed' => 'Completed',
  'cancelled' => 'Cancelled',
  _ => status,
};

Color jobStatusColor(String status) => switch (status) {
  'completed' => AppColors.statusLive,
  'cancelled' => AppColors.statusError,
  'open' => AppColors.textSecondary,
  _ => AppColors.ctaBlue,
};
