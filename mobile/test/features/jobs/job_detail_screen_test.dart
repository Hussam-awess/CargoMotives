import 'package:cargo_motives/features/jobs/data/bid_repository.dart';
import 'package:cargo_motives/features/jobs/data/job_repository.dart';
import 'package:cargo_motives/features/jobs/job_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_bid_repository.dart';
import '../../support/fake_job_bid_channel.dart';
import '../../support/fake_job_location_channel.dart';
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
  assignedTruckRegistration: null,
  assignedDriverName: null,
  proofOfDelivery: null,
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
          bidChannel: FakeJobBidChannel(jobId: 10),
          locationChannel: FakeJobLocationChannel(jobId: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dry Van · 40ft'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('ABC Logistics'), 300, scrollable: find.byType(Scrollable).first);
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
          bidChannel: channel,
          locationChannel: FakeJobLocationChannel(jobId: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('No bids yet.'), 300, scrollable: find.byType(Scrollable).first);
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
          bidChannel: FakeJobBidChannel(jobId: 10),
          locationChannel: FakeJobLocationChannel(jobId: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Accept'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm booking'), findsOneWidget);
    await tester.tap(find.text('CONFIRM BOOKING'));
    await tester.pumpAndSettle();

    expect(acceptedBidId, 1);
  });

  testWidgets('a delivered job shows proof of delivery and a Confirm Receipt button', (tester) async {
    final deliveredJob = Job(
      id: 10,
      status: 'delivered',
      pickupAddress: _openJob.pickupAddress,
      pickupLat: _openJob.pickupLat,
      pickupLng: _openJob.pickupLng,
      dropoffAddress: _openJob.dropoffAddress,
      dropoffLat: _openJob.dropoffLat,
      dropoffLng: _openJob.dropoffLng,
      containerType: _openJob.containerType,
      containerSize: _openJob.containerSize,
      approxWeightTons: _openJob.approxWeightTons,
      cargoDescription: _openJob.cargoDescription,
      preferredPickupWindowStart: _openJob.preferredPickupWindowStart,
      customerNotes: null,
      agreedPrice: 750000,
      currency: 'TZS',
      assignedCompanyName: 'ABC Logistics',
      assignedTruckRegistration: 'T 123 ABC',
      assignedDriverName: 'Ali Juma',
      proofOfDelivery: const ProofOfDelivery(
        photoUrls: ['https://example.test/photo1.jpg'],
        recipientName: 'Asha Mwinyi',
        notes: 'Left at reception.',
        confirmedByCustomerAt: null,
      ),
      bidsCount: 1,
    );

    int? confirmedJobId;
    await tester.pumpWidget(
      MaterialApp(
        home: JobDetailScreen(
          jobId: 10,
          jobRepository: FakeJobRepository(
            onShow: (_) async => deliveredJob,
            onConfirmDelivery: (jobId) async {
              confirmedJobId = jobId;
              return deliveredJob;
            },
          ),
          bidRepository: FakeBidRepository(onForJob: (_) async => []),
          bidChannel: FakeJobBidChannel(jobId: 10),
          locationChannel: FakeJobLocationChannel(jobId: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('PROOF OF DELIVERY'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('PROOF OF DELIVERY'), findsOneWidget);
    expect(find.text('Received by: Asha Mwinyi'), findsOneWidget);
    expect(find.text('Left at reception.'), findsOneWidget);
    expect(find.text('Confirm Receipt'), findsOneWidget);

    await tester.ensureVisible(find.text('Confirm Receipt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Receipt'));
    await tester.pumpAndSettle();

    expect(confirmedJobId, 10);
  });

  testWidgets('a completed job shows the confirmed proof of delivery without a button', (tester) async {
    final completedJob = Job(
      id: 10,
      status: 'completed',
      pickupAddress: _openJob.pickupAddress,
      pickupLat: _openJob.pickupLat,
      pickupLng: _openJob.pickupLng,
      dropoffAddress: _openJob.dropoffAddress,
      dropoffLat: _openJob.dropoffLat,
      dropoffLng: _openJob.dropoffLng,
      containerType: _openJob.containerType,
      containerSize: _openJob.containerSize,
      approxWeightTons: _openJob.approxWeightTons,
      cargoDescription: _openJob.cargoDescription,
      preferredPickupWindowStart: _openJob.preferredPickupWindowStart,
      customerNotes: null,
      agreedPrice: 750000,
      currency: 'TZS',
      assignedCompanyName: 'ABC Logistics',
      assignedTruckRegistration: 'T 123 ABC',
      assignedDriverName: 'Ali Juma',
      proofOfDelivery: ProofOfDelivery(
        photoUrls: const ['https://example.test/photo1.jpg'],
        recipientName: 'Asha Mwinyi',
        notes: null,
        confirmedByCustomerAt: DateTime(2026, 9, 6),
      ),
      bidsCount: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: JobDetailScreen(
          jobId: 10,
          jobRepository: FakeJobRepository(onShow: (_) async => completedJob),
          bidRepository: FakeBidRepository(onForJob: (_) async => []),
          bidChannel: FakeJobBidChannel(jobId: 10),
          locationChannel: FakeJobLocationChannel(jobId: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Confirmed'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Confirm Receipt'), findsNothing);
  });

  Job trackableJob({required bool gpsTrackingActive, String gpsSignalStatus = 'ok', GpsLocation? lastKnownLocation}) {
    return Job(
      id: 10,
      status: 'in_transit',
      pickupAddress: _openJob.pickupAddress,
      pickupLat: _openJob.pickupLat,
      pickupLng: _openJob.pickupLng,
      dropoffAddress: _openJob.dropoffAddress,
      dropoffLat: _openJob.dropoffLat,
      dropoffLng: _openJob.dropoffLng,
      containerType: _openJob.containerType,
      containerSize: _openJob.containerSize,
      approxWeightTons: _openJob.approxWeightTons,
      cargoDescription: _openJob.cargoDescription,
      preferredPickupWindowStart: _openJob.preferredPickupWindowStart,
      customerNotes: null,
      agreedPrice: 750000,
      currency: 'TZS',
      assignedCompanyName: 'ABC Logistics',
      assignedTruckRegistration: 'T 123 ABC',
      assignedDriverName: 'Ali Juma',
      proofOfDelivery: null,
      bidsCount: 1,
      gpsTrackingActive: gpsTrackingActive,
      gpsSignalStatus: gpsSignalStatus,
      lastKnownLocation: lastKnownLocation,
    );
  }

  testWidgets('a job with no GPS shows "GPS Tracking Not Available"', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: JobDetailScreen(
          jobId: 10,
          jobRepository: FakeJobRepository(onShow: (_) async => trackableJob(gpsTrackingActive: false, gpsSignalStatus: 'not_applicable')),
          bidRepository: FakeBidRepository(onForJob: (_) async => []),
          bidChannel: FakeJobBidChannel(jobId: 10),
          locationChannel: FakeJobLocationChannel(jobId: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GPS Tracking Not Available'), findsOneWidget);
  });

  testWidgets('a GPS-lost job shows the signal-unavailable state with the last known position', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: JobDetailScreen(
          jobId: 10,
          jobRepository: FakeJobRepository(
            onShow: (_) async => trackableJob(
              gpsTrackingActive: true,
              gpsSignalStatus: 'lost',
              lastKnownLocation: GpsLocation(lat: -6.8161, lng: 39.2803, heading: 90, recordedAt: DateTime.now().subtract(const Duration(minutes: 20))),
            ),
          ),
          bidRepository: FakeBidRepository(onForJob: (_) async => []),
          bidChannel: FakeJobBidChannel(jobId: 10),
          locationChannel: FakeJobLocationChannel(jobId: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GPS signal unavailable'), findsOneWidget);
  });

  testWidgets('a live-tracking job shows the live position and updates from a socket push', (tester) async {
    final locationChannel = FakeJobLocationChannel(jobId: 10);
    await tester.pumpWidget(
      MaterialApp(
        home: JobDetailScreen(
          jobId: 10,
          jobRepository: FakeJobRepository(
            onShow: (_) async => trackableJob(
              gpsTrackingActive: true,
              lastKnownLocation: GpsLocation(lat: -6.8, lng: 39.2, heading: 0, recordedAt: DateTime.now()),
            ),
          ),
          bidRepository: FakeBidRepository(onForJob: (_) async => []),
          bidChannel: FakeJobBidChannel(jobId: 10),
          locationChannel: locationChannel,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Live'), findsOneWidget);
    expect(find.text('-6.8000, 39.2000'), findsOneWidget);

    locationChannel.emitLocation({'lat': -6.85, 'lng': 39.25, 'heading': 180, 'recorded_at': DateTime.now().toIso8601String()});
    await tester.pump();

    expect(find.text('-6.8500, 39.2500'), findsOneWidget);
  });
}
