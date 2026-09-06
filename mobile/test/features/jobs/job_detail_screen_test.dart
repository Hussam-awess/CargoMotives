import 'package:cargo_motives/features/jobs/data/bid_repository.dart';
import 'package:cargo_motives/features/jobs/data/job_repository.dart';
import 'package:cargo_motives/features/jobs/job_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_bid_repository.dart';
import '../../support/fake_job_bid_channel.dart';
import '../../support/fake_job_repository.dart';

final _openJob = Job(
  id: 10,
  status: 'open',
  pickupAddress: 'Kariakoo',
  pickupLat: -6.8,
  pickupLng: 39.2,
  dropoffAddress: 'Mbezi Beach',
  dropoffLat: -6.7,
  dropoffLng: 39.1,
  containerType: 'Dry Van',
  containerSize: '40ft',
  approxWeightTons: 12,
  cargoDescription: null,
  preferredPickupWindowStart: DateTime(2026, 9, 10, 9),
  customerNotes: null,
  agreedPrice: null,
  currency: 'TZS',
  assignedCompanyName: null,
  bidsCount: 1,
);

const _company = BidCompany(id: 1, name: 'ABC Logistics', verified: true, truckCount: 5, gpsAvailable: true, rating: 4.8, ratingCount: 20);

const _pendingBid = Bid(
  id: 1,
  jobId: 10,
  price: 750000,
  estimatedPickupTime: null,
  note: 'Can pick up today',
  status: 'pending',
  isPriority: false,
  company: _company,
);

void main() {
  testWidgets('shows the job summary and its bid list', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: JobDetailScreen(
          jobId: 10,
          jobRepository: FakeJobRepository(onShow: (_) async => _openJob),
          bidRepository: FakeBidRepository(onForJob: (_) async => [_pendingBid]),
          channel: FakeJobBidChannel(jobId: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dry Van · 40ft'), findsOneWidget);
    expect(find.textContaining('ABC Logistics'), findsOneWidget);
    expect(find.text('TZS 750000'), findsOneWidget);
    expect(find.text('Live GPS Available'), findsOneWidget);
  });

  testWidgets('a live bid pushed over the socket appears without a manual refresh', (tester) async {
    final channel = FakeJobBidChannel(jobId: 10);
    await tester.pumpWidget(
      MaterialApp(
        home: JobDetailScreen(
          jobId: 10,
          jobRepository: FakeJobRepository(onShow: (_) async => _openJob),
          bidRepository: FakeBidRepository(onForJob: (_) async => []),
          channel: channel,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No bids yet.'), findsOneWidget);

    channel.emitBid({
      'id': 2,
      'job_id': 10,
      'price': 500000,
      'estimated_pickup_time': null,
      'note': null,
      'status': 'pending',
      'is_priority': false,
      'company': {'id': 2, 'name': 'XYZ Transport', 'verified': true, 'truck_count': 3, 'gps_available': false, 'rating': null, 'rating_count': 0},
    });
    await tester.pump();

    expect(find.textContaining('XYZ Transport'), findsOneWidget);
    expect(find.text('No bids yet.'), findsNothing);
  });

  testWidgets('accepting a bid calls the repository and reloads', (tester) async {
    int? acceptedBidId;
    await tester.pumpWidget(
      MaterialApp(
        home: JobDetailScreen(
          jobId: 10,
          jobRepository: FakeJobRepository(onShow: (_) async => _openJob),
          bidRepository: FakeBidRepository(
            onForJob: (_) async => [_pendingBid],
            onAccept: (bidId) async {
              acceptedBidId = bidId;
              return (job: _openJob, bid: _pendingBid);
            },
          ),
          channel: FakeJobBidChannel(jobId: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(acceptedBidId, 1);
  });
}
