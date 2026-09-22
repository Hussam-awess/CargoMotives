import 'package:cargo_motives/core/theme/app_theme.dart';
import 'package:cargo_motives/features/auth/data/auth_repository.dart';
import 'package:cargo_motives/features/jobs/data/bid_repository.dart';
import 'package:cargo_motives/features/jobs/data/job_repository.dart';
import 'package:cargo_motives/features/jobs/job_detail_screen.dart';
import 'package:cargo_motives/features/jobs/messages_screen.dart';
import 'package:cargo_motives/features/jobs/post_job_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
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

const _company = BidCompany(
  id: 1,
  name: 'ABC Logistics',
  verified: true,
  truckCount: 5,
  gpsAvailable: true,
  rating: 4.8,
  ratingCount: 20,
);

Job _jobWithStatus(String status) => Job(
  id: 10,
  status: status,
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
  bidsCount: 0,
);

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
          bidRepository: FakeBidRepository(
            onForJob: (_) async => [_pendingBid],
          ),
          bidChannel: FakeJobBidChannel(jobId: 10),
          locationChannel: FakeJobLocationChannel(jobId: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dry Van · 40ft'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('ABC Logistics'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('ABC Logistics'), findsOneWidget);
    expect(find.text('TZS 750000'), findsOneWidget);
    expect(find.text('Live GPS Available'), findsOneWidget);
  });

  testWidgets('a bid\'s company name is wired to open their public profile', (
    tester,
  ) async {
    // Navigating for real would hit the live ProfileRepository (no fake
    // injection point at this call site) and hang the test on a real
    // network call, so this verifies the tap target itself is wired
    // rather than following it.
    await tester.pumpWidget(
      MaterialApp(
        home: JobDetailScreen(
          jobId: 10,
          jobRepository: FakeJobRepository(onShow: (_) async => _openJob),
          bidRepository: FakeBidRepository(
            onForJob: (_) async => [_pendingBid],
          ),
          bidChannel: FakeJobBidChannel(jobId: 10),
          locationChannel: FakeJobLocationChannel(jobId: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.textContaining('ABC Logistics'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final inkWell = tester.widget<InkWell>(
      find
          .ancestor(
            of: find.textContaining('ABC Logistics'),
            matching: find.byType(InkWell),
          )
          .first,
    );
    expect(inkWell.onTap, isNotNull);
  });

  testWidgets(
    'a live bid pushed over the socket appears without a manual refresh',
    (tester) async {
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

      await tester.scrollUntilVisible(
        find.text('No bids yet.'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('No bids yet.'), findsOneWidget);

      channel.emitBid({
        'id': 2,
        'job_id': 10,
        'price': 500000,
        'estimated_pickup_time': null,
        'note': null,
        'status': 'pending',
        'is_priority': false,
        'company': {
          'id': 2,
          'name': 'XYZ Transport',
          'verified': true,
          'truck_count': 3,
          'gps_available': false,
          'rating': null,
          'rating_count': 0,
        },
      });
      await tester.pump();

      expect(find.textContaining('XYZ Transport'), findsOneWidget);
      expect(find.text('No bids yet.'), findsNothing);
    },
  );

  testWidgets('accepting a bid calls the repository and reloads', (
    tester,
  ) async {
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

    await tester.scrollUntilVisible(
      find.text('Accept'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // scrollUntilVisible stops as soon as any part of the target is
    // hit-testable, which can leave its exact center (what tap() uses)
    // just past the viewport edge — ensureVisible scrolls precisely
    // enough that the whole widget, center included, is on-screen.
    await tester.ensureVisible(find.text('Accept'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm booking'), findsOneWidget);
    await tester.tap(find.text('CONFIRM BOOKING'));
    await tester.pumpAndSettle();

    expect(acceptedBidId, 1);
  });

  testWidgets(
    'the assigned transporter\'s name is wired to open their public profile',
    (tester) async {
      final assignedJob = Job(
        id: 10,
        status: 'en_route_pickup',
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
        assignedCompanyId: 3,
        assignedCompanyName: 'ABC Logistics',
        assignedTruckRegistration: 'T 123 ABC',
        assignedDriverName: 'Ali Juma',
        proofOfDelivery: null,
        bidsCount: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: JobDetailScreen(
            jobId: 10,
            jobRepository: FakeJobRepository(onShow: (_) async => assignedJob),
            bidRepository: FakeBidRepository(onForJob: (_) async => []),
            bidChannel: FakeJobBidChannel(jobId: 10),
            locationChannel: FakeJobLocationChannel(jobId: 10),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Ali Juma'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final inkWell = tester.widget<InkWell>(
        find
            .ancestor(of: find.text('Ali Juma'), matching: find.byType(InkWell))
            .first,
      );
      expect(inkWell.onTap, isNotNull);
    },
  );

  testWidgets(
    'opening Messages on an assigned job shows the driver\'s name as a subtitle',
    (tester) async {
      final assignedJob = Job(
        id: 10,
        status: 'en_route_pickup',
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
        assignedCompanyId: 3,
        assignedCompanyName: 'ABC Logistics',
        assignedTruckRegistration: 'T 123 ABC',
        assignedDriverName: 'Ali Juma',
        proofOfDelivery: null,
        bidsCount: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: JobDetailScreen(
            jobId: 10,
            jobRepository: FakeJobRepository(onShow: (_) async => assignedJob),
            bidRepository: FakeBidRepository(onForJob: (_) async => []),
            bidChannel: FakeJobBidChannel(jobId: 10),
            locationChannel: FakeJobLocationChannel(jobId: 10),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A plain pump, not pumpAndSettle: MessagesScreen's default
      // MessageRepository hits the real network, which never resolves in
      // a widget test — this only needs to confirm what it was pushed
      // with, not wait for its own data to load.
      await tester.tap(find.byTooltip('Messages'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final messagesScreen = tester.widget<MessagesScreen>(
        find.byType(MessagesScreen),
      );
      expect(messagesScreen.counterpartyName, 'ABC Logistics');
      expect(messagesScreen.counterpartySubtitle, 'Driver: Ali Juma');
    },
  );

  testWidgets(
    'a delivered job shows proof of delivery and a Confirm Receipt button',
    (tester) async {
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

      await tester.scrollUntilVisible(
        find.text('PROOF OF DELIVERY'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('PROOF OF DELIVERY'), findsOneWidget);
      expect(find.text('Received by: Asha Mwinyi'), findsOneWidget);
      expect(find.text('Left at reception.'), findsOneWidget);
      expect(find.text('Confirm Receipt'), findsOneWidget);

      await tester.ensureVisible(find.text('Confirm Receipt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm Receipt'));
      await tester.pumpAndSettle();

      expect(confirmedJobId, 10);
    },
  );

  testWidgets(
    'a completed job shows the confirmed proof of delivery without a button',
    (tester) async {
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
        completedAt: DateTime(2026, 9, 6, 10, 15),
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

      await tester.scrollUntilVisible(
        find.text('Confirmed'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Confirm Receipt'), findsNothing);
      // The real completion timestamp, not the job's scheduled pickup window.
      expect(find.text('Completed on 6 September 2026'), findsOneWidget);
    },
  );

  testWidgets(
    'shows the Rate your experience prompt when the job is reviewable and opens the rating screen',
    (tester) async {
      final reviewableJob = Job(
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
        proofOfDelivery: null,
        bidsCount: 1,
        reviewable: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: JobDetailScreen(
            jobId: 10,
            jobRepository: FakeJobRepository(
              onShow: (_) async => reviewableJob,
            ),
            bidRepository: FakeBidRepository(onForJob: (_) async => []),
            bidChannel: FakeJobBidChannel(jobId: 10),
            locationChannel: FakeJobLocationChannel(jobId: 10),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Rate your experience'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Rate your experience'));
      await tester.pumpAndSettle();

      // customerRatingTransporter's category labels confirm the direction
      // wired from this (customer-facing) screen is correct.
      expect(find.text('On-time pickup'), findsOneWidget);
    },
  );

  Job trackableJob({
    required bool gpsTrackingActive,
    String gpsSignalStatus = 'ok',
    GpsLocation? lastKnownLocation,
  }) {
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

  testWidgets('a job with no GPS shows "GPS Tracking Not Available"', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: JobDetailScreen(
          jobId: 10,
          jobRepository: FakeJobRepository(
            onShow: (_) async => trackableJob(
              gpsTrackingActive: false,
              gpsSignalStatus: 'not_applicable',
            ),
          ),
          bidRepository: FakeBidRepository(onForJob: (_) async => []),
          bidChannel: FakeJobBidChannel(jobId: 10),
          locationChannel: FakeJobLocationChannel(jobId: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GPS Tracking Not Available'), findsOneWidget);
  });

  testWidgets(
    'a GPS-lost job shows the signal-unavailable state with the last known position',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: JobDetailScreen(
            jobId: 10,
            jobRepository: FakeJobRepository(
              onShow: (_) async => trackableJob(
                gpsTrackingActive: true,
                gpsSignalStatus: 'lost',
                lastKnownLocation: GpsLocation(
                  lat: -6.8161,
                  lng: 39.2803,
                  heading: 90,
                  recordedAt: DateTime.now().subtract(
                    const Duration(minutes: 20),
                  ),
                ),
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
    },
  );

  testWidgets(
    'a live-tracking job shows the live position and updates from a socket push',
    (tester) async {
      final locationChannel = FakeJobLocationChannel(jobId: 10);
      await tester.pumpWidget(
        MaterialApp(
          home: JobDetailScreen(
            jobId: 10,
            jobRepository: FakeJobRepository(
              onShow: (_) async => trackableJob(
                gpsTrackingActive: true,
                lastKnownLocation: GpsLocation(
                  lat: -6.8,
                  lng: 39.2,
                  heading: 0,
                  recordedAt: DateTime.now(),
                ),
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

      locationChannel.emitLocation({
        'lat': -6.85,
        'lng': 39.25,
        'heading': 180,
        'recorded_at': DateTime.now().toIso8601String(),
      });
      await tester.pump();

      expect(find.text('-6.8500, 39.2500'), findsOneWidget);
    },
  );

  Job completedJobForReturn() => Job(
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

  testWidgets(
    'a Plus customer sees "Post return shipment" on a completed job and it opens Post Job pre-filled',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: JobDetailScreen(
            jobId: 10,
            jobRepository: FakeJobRepository(
              onShow: (_) async => completedJobForReturn(),
            ),
            bidRepository: FakeBidRepository(onForJob: (_) async => []),
            bidChannel: FakeJobBidChannel(jobId: 10),
            locationChannel: FakeJobLocationChannel(jobId: 10),
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(
                fullName: 'Test User',
                companyName: null,
                isFeatured: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Post return shipment'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Post return shipment'), findsOneWidget);

      await tester.tap(find.text('Post return shipment'));
      await tester.pumpAndSettle();

      expect(find.byType(PostJobScreen), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, _openJob.dropoffAddress),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextFormField, _openJob.pickupAddress),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a standard customer does not see "Post return shipment" on a completed job',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: JobDetailScreen(
            jobId: 10,
            jobRepository: FakeJobRepository(
              onShow: (_) async => completedJobForReturn(),
            ),
            bidRepository: FakeBidRepository(onForJob: (_) async => []),
            bidChannel: FakeJobBidChannel(jobId: 10),
            locationChannel: FakeJobLocationChannel(jobId: 10),
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(
                fullName: 'Test User',
                companyName: null,
                isFeatured: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Post return shipment'), findsNothing);
    },
  );

  testWidgets(
    'a split job shows one card per award and confirms delivery independently',
    (tester) async {
      final splitJob = Job(
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
        trucksNeeded: 20,
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
        bidsCount: 2,
        awards: const [
          JobAward(
            id: 1,
            companyId: 1,
            companyName: 'Doc Test Logistics',
            trucksOffered: 8,
            agreedPrice: 400000,
            status: 'in_transit',
          ),
          JobAward(
            id: 2,
            companyId: 2,
            companyName: 'Second Carrier',
            trucksOffered: 12,
            agreedPrice: 600000,
            status: 'delivered',
            proofOfDelivery: ProofOfDelivery(
              photoUrls: ['https://example.test/pod.jpg'],
              recipientName: 'Asha',
              notes: null,
              confirmedByCustomerAt: null,
            ),
          ),
        ],
      );

      int? confirmedAwardId;
      await tester.pumpWidget(
        MaterialApp(
          home: JobDetailScreen(
            jobId: 10,
            jobRepository: FakeJobRepository(
              onShow: (_) async => splitJob,
              onConfirmAwardDelivery: (jobId, awardId) async {
                confirmedAwardId = awardId;
                return splitJob;
              },
            ),
            bidRepository: FakeBidRepository(onForJob: (_) async => []),
            bidChannel: FakeJobBidChannel(jobId: 10),
            locationChannel: FakeJobLocationChannel(jobId: 10),
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(
                fullName: 'Test User',
                companyName: null,
                isFeatured: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Doc Test Logistics'), findsOneWidget);
      expect(find.text('Second Carrier'), findsOneWidget);
      // The single-company legacy timeline/transporter card never renders.
      expect(find.text('TRANSPORTER'), findsNothing);

      await tester.ensureVisible(find.text('Confirm Receipt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm Receipt'));
      await tester.pumpAndSettle();

      expect(confirmedAwardId, 2);
    },
  );

  testWidgets(
    'a bidding-closed job with no bids shows the red banner and Repost buttons',
    (tester) async {
      final closedJob = Job(
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
        preferredPickupWindowStart: DateTime(2026, 9, 25, 9),
        customerNotes: null,
        agreedPrice: null,
        currency: 'TZS',
        assignedCompanyName: null,
        assignedTruckRegistration: null,
        assignedDriverName: null,
        proofOfDelivery: null,
        bidsCount: 0,
        biddingExpiresAt: DateTime(2026, 9, 22, 18),
        biddingClosed: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: JobDetailScreen(
            jobId: 10,
            jobRepository: FakeJobRepository(onShow: (_) async => closedJob),
            bidRepository: FakeBidRepository(onForJob: (_) async => []),
            bidChannel: FakeJobBidChannel(jobId: 10),
            locationChannel: FakeJobLocationChannel(jobId: 10),
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(
                fullName: 'Test User',
                companyName: null,
                isFeatured: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Bidding Closed'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Bidding Closed'), findsOneWidget);
      expect(find.text('Repost Job'), findsOneWidget);
      expect(find.text('Edit & Repost'), findsOneWidget);
      expect(find.text('No bids yet.'), findsNothing);

      await tester.tap(find.text('Repost Job'));
      await tester.pumpAndSettle();

      expect(find.byType(PostJobScreen), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Kariakoo'), findsOneWidget);
    },
  );

  testWidgets(
    'a bidding-closed job with pending bids shows the yellow banner and the untouched bid list',
    (tester) async {
      final closedJob = Job(
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
        preferredPickupWindowStart: DateTime(2026, 9, 25, 9),
        customerNotes: null,
        agreedPrice: null,
        currency: 'TZS',
        assignedCompanyName: null,
        assignedTruckRegistration: null,
        assignedDriverName: null,
        proofOfDelivery: null,
        bidsCount: 1,
        biddingExpiresAt: DateTime(2026, 9, 22, 18),
        biddingClosed: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: JobDetailScreen(
            jobId: 10,
            jobRepository: FakeJobRepository(onShow: (_) async => closedJob),
            bidRepository: FakeBidRepository(
              onForJob: (_) async => [_pendingBid],
            ),
            bidChannel: FakeJobBidChannel(jobId: 10),
            locationChannel: FakeJobLocationChannel(jobId: 10),
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(
                fullName: 'Test User',
                companyName: null,
                isFeatured: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Bidding Closed — Select a Transporter'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(
        find.text('Bidding Closed — Select a Transporter'),
        findsOneWidget,
      );
      expect(find.text('Repost Job'), findsNothing);
      await tester.scrollUntilVisible(
        find.textContaining('ABC Logistics'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('ABC Logistics'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
    },
  );

  testWidgets('a Plus customer sees how many transporters viewed the job', (
    tester,
  ) async {
    final viewedJob = Job(
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
      jobViewsCount: 4,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: JobDetailScreen(
          jobId: 10,
          jobRepository: FakeJobRepository(onShow: (_) async => viewedJob),
          bidRepository: FakeBidRepository(onForJob: (_) async => []),
          bidChannel: FakeJobBidChannel(jobId: 10),
          locationChannel: FakeJobLocationChannel(jobId: 10),
          authRepository: FakeAuthRepository(
            onMe: () async => const UserProfile(
              fullName: 'Test User',
              companyName: null,
              isFeatured: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Bids (0)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('4'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('a non-Plus customer does not see the job-views badge', (
    tester,
  ) async {
    final viewedJob = Job(
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
      jobViewsCount: 4,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: JobDetailScreen(
          jobId: 10,
          jobRepository: FakeJobRepository(onShow: (_) async => viewedJob),
          bidRepository: FakeBidRepository(onForJob: (_) async => []),
          bidChannel: FakeJobBidChannel(jobId: 10),
          locationChannel: FakeJobLocationChannel(jobId: 10),
          authRepository: FakeAuthRepository(
            onMe: () async => const UserProfile(
              fullName: 'Test User',
              companyName: null,
              isFeatured: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
  });

  testWidgets('a return-load claim bid shows a distinct badge, not FEATURED', (
    tester,
  ) async {
    const claimBid = Bid(
      id: 2,
      jobId: 10,
      price: 300000,
      estimatedPickupTime: null,
      note: null,
      status: 'pending',
      isPriority: true,
      company: _company,
      isReturnLoadClaim: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: JobDetailScreen(
          jobId: 10,
          jobRepository: FakeJobRepository(onShow: (_) async => _openJob),
          bidRepository: FakeBidRepository(onForJob: (_) async => [claimBid]),
          bidChannel: FakeJobBidChannel(jobId: 10),
          locationChannel: FakeJobLocationChannel(jobId: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.textContaining('RETURN LOAD MATCH'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('RETURN LOAD MATCH'), findsOneWidget);
    expect(find.text('FEATURED'), findsNothing);
  });

  testWidgets(
    'the timeline shows all six stages, including In transit as its own step',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: JobDetailScreen(
            jobId: 10,
            jobRepository: FakeJobRepository(
              onShow: (_) async => _jobWithStatus('in_transit'),
            ),
            bidRepository: FakeBidRepository(onForJob: (_) async => []),
            bidChannel: FakeJobBidChannel(jobId: 10),
            locationChannel: FakeJobLocationChannel(jobId: 10),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Completed'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Shipment posted'), findsOneWidget);
      expect(find.text('Transporter assigned'), findsOneWidget);
      expect(find.text('Loading cargo'), findsOneWidget);
      // In transit is a distinct stage now, not folded into "Loading cargo".
      expect(find.text('In transit'), findsOneWidget);
      expect(find.text('Delivered'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);

      // The current stage's icon renders alongside the earlier, already-
      // passed stages' icons — same truck glyph Fleet Management uses for
      // a truck itself marks "Transporter assigned" here too.
      expect(find.byIcon(Icons.local_shipping_outlined), findsOneWidget);
      expect(find.byIcon(Icons.local_shipping), findsOneWidget);
    },
  );

  testWidgets(
    'a job stuck en route to pickup still reads as Transporter assigned, not a phantom stage',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: JobDetailScreen(
            jobId: 10,
            jobRepository: FakeJobRepository(
              onShow: (_) async => _jobWithStatus('en_route_pickup'),
            ),
            bidRepository: FakeBidRepository(onForJob: (_) async => []),
            bidChannel: FakeJobBidChannel(jobId: 10),
            locationChannel: FakeJobLocationChannel(jobId: 10),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Loading cargo'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      // "Transporter assigned" is the current (highlighted) stage; "Loading
      // cargo" and everything after it hasn't happened yet.
      final assignedIcon = tester.widget<Icon>(
        find.descendant(
          of: find.ancestor(
            of: find.text('Transporter assigned'),
            matching: find.byType(Row),
          ),
          matching: find.byIcon(Icons.local_shipping_outlined),
        ),
      );
      expect(assignedIcon.color, isNot(AppColors.textTertiary));
    },
  );
}
