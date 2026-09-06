import 'package:cargo_motives/core/network/api_exception.dart';
import 'package:cargo_motives/features/company/jobs/company_job_detail_screen.dart';
import 'package:cargo_motives/features/jobs/data/bid_repository.dart';
import 'package:cargo_motives/features/jobs/data/job_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_bid_repository.dart';
import '../../../support/fake_company_job_repository.dart';
import '../../../support/fake_job_assignment_repository.dart';
import '../../../support/fake_job_location_channel.dart';

final _openJob = Job(
  id: 5,
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
  cargoDescription: 'General cargo',
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

void main() {
  testWidgets('shows the job and remaining bid quota', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyJobDetailScreen(
          jobId: 5,
          jobRepository: FakeCompanyJobRepository(onShow: (_) async => _openJob),
          bidRepository: FakeBidRepository(onCompanyQuotaRemaining: () async => 3),
          locationChannel: FakeJobLocationChannel(jobId: 5),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dry Van · 40ft'), findsOneWidget);
    expect(find.text('3 bid(s) remaining'), findsOneWidget);
  });

  testWidgets('places a bid and shows the pending confirmation', (tester) async {
    double? capturedPrice;
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyJobDetailScreen(
          jobId: 5,
          jobRepository: FakeCompanyJobRepository(onShow: (_) async => _openJob),
          bidRepository: FakeBidRepository(
            onCompanyQuotaRemaining: () async => 3,
            onPlace: ({required jobId, required price, estimatedPickupTime, note}) async {
              capturedPrice = price;
              return Bid(
                id: 1,
                jobId: jobId,
                price: price,
                estimatedPickupTime: null,
                note: note,
                status: 'pending',
                isPriority: false,
                company: const BidCompany(id: 1, name: 'ABC', verified: true, truckCount: 1, gpsAvailable: false, rating: null, ratingCount: 0),
              );
            },
          ),
          locationChannel: FakeJobLocationChannel(jobId: 5),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Price (TZS)'), '750000');
    await tester.tap(find.text('Place bid'));
    await tester.pumpAndSettle();

    expect(capturedPrice, 750000);
    expect(find.text('Bid placed: TZS 750000 — pending review.'), findsOneWidget);
  });

  testWidgets('rejects an invalid price without calling the repository', (tester) async {
    var placeCalled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyJobDetailScreen(
          jobId: 5,
          jobRepository: FakeCompanyJobRepository(onShow: (_) async => _openJob),
          bidRepository: FakeBidRepository(
            onCompanyQuotaRemaining: () async => 3,
            onPlace: ({required jobId, required price, estimatedPickupTime, note}) async {
              placeCalled = true;
              throw StateError('should not be called');
            },
          ),
          locationChannel: FakeJobLocationChannel(jobId: 5),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Place bid'));
    await tester.pump();

    expect(find.text('Enter a valid price.'), findsOneWidget);
    expect(placeCalled, isFalse);
  });

  testWidgets('shows a quota-exceeded message with the reset time', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyJobDetailScreen(
          jobId: 5,
          jobRepository: FakeCompanyJobRepository(onShow: (_) async => _openJob),
          bidRepository: FakeBidRepository(
            onCompanyQuotaRemaining: () async => 1,
            onPlace: ({required jobId, required price, estimatedPickupTime, note}) async {
              throw ApiException('Bid limit reached.', body: {'seconds_until_slot_frees': 600});
            },
          ),
          locationChannel: FakeJobLocationChannel(jobId: 5),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Price (TZS)'), '500000');
    await tester.tap(find.text('Place bid'));
    await tester.pumpAndSettle();

    expect(find.text('Bid limit reached. Try again in 10 min.'), findsOneWidget);
  });

  testWidgets('a job that is no longer open shows no bid form', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyJobDetailScreen(
          jobId: 5,
          jobRepository: FakeCompanyJobRepository(
            onShow: (_) async => Job(
              id: 5,
              status: 'assigned',
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
              agreedPrice: null,
              currency: 'TZS',
              assignedCompanyName: 'Another Co',
              assignedTruckRegistration: null,
              assignedDriverName: null,
              proofOfDelivery: null,
              bidsCount: 1,
            ),
          ),
          bidRepository: FakeBidRepository(onCompanyQuotaRemaining: () async => 3),
          locationChannel: FakeJobLocationChannel(jobId: 5),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This job is no longer open for bidding.'), findsOneWidget);
    expect(find.text('Place bid'), findsNothing);
  });

  testWidgets('the assigned company sees the assignment section, not the bid form', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyJobDetailScreen(
          jobId: 5,
          jobRepository: FakeCompanyJobRepository(
            onShow: (_) async => Job(
              id: 5,
              status: 'assigned',
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
              agreedPrice: null,
              currency: 'TZS',
              assignedCompanyName: null,
              assignedTruckRegistration: null,
              assignedDriverName: null,
              proofOfDelivery: null,
              bidsCount: 0,
              isAssignedToViewer: true,
            ),
          ),
          bidRepository: FakeBidRepository(onCompanyQuotaRemaining: () async => 3),
          locationChannel: FakeJobLocationChannel(jobId: 5),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No truck/driver assigned yet.'), findsOneWidget);
    expect(find.text('Assign truck & driver'), findsOneWidget);
    expect(find.text('Place bid'), findsNothing);
    expect(find.text('This job is no longer open for bidding.'), findsNothing);
  });

  testWidgets('once a truck/driver is assigned, shows their names and a driver-link action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyJobDetailScreen(
          jobId: 5,
          jobRepository: FakeCompanyJobRepository(
            onShow: (_) async => Job(
              id: 5,
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
              agreedPrice: null,
              currency: 'TZS',
              assignedCompanyName: null,
              assignedTruckRegistration: 'T 123 ABC',
              assignedDriverName: 'Ali Juma',
              proofOfDelivery: null,
              bidsCount: 0,
              isAssignedToViewer: true,
            ),
          ),
          bidRepository: FakeBidRepository(onCompanyQuotaRemaining: () async => 3),
          assignmentRepository: FakeJobAssignmentRepository(),
          locationChannel: FakeJobLocationChannel(jobId: 5),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('T 123 ABC · Ali Juma'), findsOneWidget);
    expect(find.text('Reassign truck & driver'), findsOneWidget);
    expect(find.text('View driver link'), findsOneWidget);
    expect(find.text('GPS Tracking Not Available'), findsOneWidget);
  });

  testWidgets('a GPS-connected truck shows live position and updates from a socket push', (tester) async {
    final locationChannel = FakeJobLocationChannel(jobId: 5);
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyJobDetailScreen(
          jobId: 5,
          jobRepository: FakeCompanyJobRepository(
            onShow: (_) async => Job(
              id: 5,
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
              agreedPrice: null,
              currency: 'TZS',
              assignedCompanyName: null,
              assignedTruckRegistration: 'T 123 ABC',
              assignedDriverName: 'Ali Juma',
              proofOfDelivery: null,
              bidsCount: 0,
              isAssignedToViewer: true,
              gpsTrackingActive: true,
              gpsSignalStatus: 'ok',
              lastKnownLocation: GpsLocation(lat: -6.8, lng: 39.2, heading: 90, recordedAt: DateTime.now()),
            ),
          ),
          bidRepository: FakeBidRepository(onCompanyQuotaRemaining: () async => 3),
          assignmentRepository: FakeJobAssignmentRepository(),
          locationChannel: locationChannel,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Live'), findsOneWidget);
    expect(find.text('-6.8000, 39.2000'), findsOneWidget);

    locationChannel.emitLocation({'lat': -6.81, 'lng': 39.21, 'heading': 95, 'recorded_at': DateTime.now().toIso8601String()});
    await tester.pump();

    expect(find.text('-6.8100, 39.2100'), findsOneWidget);
  });
}
