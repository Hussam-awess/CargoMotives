import 'package:cargo_motives/features/notifications/notification_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('support_message routes to support', () {
    expect(destinationFor('support_message'), NotificationDestination.support);
  });

  test('truck_approved and truck_rejected route to fleet', () {
    expect(destinationFor('truck_approved'), NotificationDestination.fleet);
    expect(destinationFor('truck_rejected'), NotificationDestination.fleet);
  });

  test('job-linked types route to job', () {
    for (final type in [
      'new_job_posted',
      'new_bid',
      'bid_placed',
      'bid_accepted',
      'bid_not_selected',
      'bid_rejected',
      'bid_withdrawn',
      'proof_of_delivery_submitted',
      'delivery_confirmed',
      'gps_signal_lost',
      'job_status_changed',
      'job_arrived_at_dropoff',
      'new_message',
      'bidding_closed_no_bids',
      'bidding_closed_has_bids',
    ]) {
      expect(destinationFor(type), NotificationDestination.job, reason: type);
    }
  });

  test('verification-outcome and unknown types have no destination', () {
    for (final type in [
      'company_approved',
      'company_rejected',
      'company_flagged_duplicate',
      're_engagement',
      'something_new_and_unhandled',
    ]) {
      expect(destinationFor(type), NotificationDestination.none, reason: type);
    }
  });
}
