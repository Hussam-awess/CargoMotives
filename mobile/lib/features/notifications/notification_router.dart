/// Where tapping a notification of a given `type` should navigate — the
/// single place every screen that renders an AppNotification list
/// (NotificationsScreen, CustomerJobsTab's Recent Activity feed) dispatches
/// through, so a new notification type only needs teaching its destination
/// once rather than at every render site independently (the bug this fixes:
/// `support_message` notifications had no destination anywhere and were
/// silent dead taps).
enum NotificationDestination { job, support, fleet, none }

/// `company_approved`/`company_rejected`/`company_flagged_duplicate` are
/// deliberately [NotificationDestination.none]: CompanyHomeGate already
/// re-fetches and shows the live verification status as the entire home
/// surface the moment the company opens the app, so there's no additional
/// screen worth pushing — the notification still marks itself read on tap,
/// it just doesn't navigate anywhere further.
NotificationDestination destinationFor(String type) => switch (type) {
  'support_message' => NotificationDestination.support,
  'truck_approved' || 'truck_rejected' => NotificationDestination.fleet,
  'new_job_posted' ||
  'new_bid' ||
  'return_load_claim' ||
  'bid_placed' ||
  'bid_accepted' ||
  'bid_not_selected' ||
  'bid_rejected' ||
  'bid_withdrawn' ||
  'proof_of_delivery_submitted' ||
  'delivery_confirmed' ||
  'gps_signal_lost' ||
  'job_status_changed' ||
  'job_arrived_at_dropoff' ||
  'new_message' ||
  'job_completed_rate_prompt' ||
  'bidding_closed_no_bids' ||
  'bidding_closed_has_bids' => NotificationDestination.job,
  _ => NotificationDestination.none,
};
