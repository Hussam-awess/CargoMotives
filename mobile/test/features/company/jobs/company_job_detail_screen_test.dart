import 'package:cargo_motives/core/network/api_exception.dart';
import 'package:cargo_motives/features/company/jobs/company_job_detail_screen.dart';
import 'package:cargo_motives/features/jobs/data/bid_repository.dart';
import 'package:cargo_motives/features/jobs/data/job_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_bid_repository.dart';
import '../../../support/fake_company_job_repository.dart';
import '../../../support/fake_follow_repository.dart';
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
  testWidgets('shows the customer\'s budget when the job has one', (
    tester,
  ) async {
    final jobWithBudget = Job(
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
      budgetPrice: 850000,
      agreedPrice: null,
      currency: 'TZS',
      assignedCompanyName: null,
      assignedTruckRegistration: null,
      assignedDriverName: null,
      proofOfDelivery: null,
      bidsCount: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CompanyJobDetailScreen(
          jobId: 5,
          jobRepository: FakeCompanyJobRepository(
            onShow: (_) async => jobWithBudget,
          ),
          bidRepository: FakeBidRepository(
            onCompanyQuotaRemaining: () async => 3,
          ),
          locationChannel: FakeJobLocationChannel(jobId: 5),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Customer\'s budget'), findsOneWidget);
    expect(find.text('TZS 850000'), findsOneWidget);
  });

  testWidgets('the "view route on map" icon is wired up', (tester) async {
    // Navigating for real would hit the live RoutingService (no fake
    // injection point at this call site) and could hang the test on a
    // real network call, so this verifies the tap target itself is wired
    // rather than following it — same pattern already used for the
    // customer/company profile tap targets elsewhere in this file.
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyJobDetailScreen(
          jobId: 5,
          jobRepository: FakeCompanyJobRepository(
            onShow: (_) async => _openJob,
          ),
          bidRepository: FakeBidRepository(
            onCompanyQuotaRemaining: () async => 3,
          ),
          locationChannel: FakeJobLocationChannel(jobId: 5),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final iconButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.map_outlined),
        matching: find.byType(IconButton),
      ),
    );
    expect(iconButton.onPressed, isNotNull);
  });

  testWidgets('a bulk job\'s bid form shows a per-truck budget notice', (
    tester,
  ) async {
    final bulkJob = Job(
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
      trucksNeeded: 20,
      approxWeightTons: 12,
      cargoDescription: null,
      preferredPickupWindowStart: DateTime(2026, 9, 10, 9),
      customerNotes: null,
      budgetPrice: 500000,
      agreedPrice: null,
      currency: 'TZS',
      assignedCompanyName: null,
      assignedTruckRegistration: null,
      assignedDriverName: null,
      proofOfDelivery: null,
      bidsCount: 0,
      remainingTrucksNeeded: 20,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CompanyJobDetailScreen(
          jobId: 5,
          jobRepository: FakeCompanyJobRepository(onShow: (_) async => bulkJob),
          bidRepository: FakeBidRepository(
            onCompanyQuotaRemaining: () async => 3,
          ),
          locationChannel: FakeJobLocationChannel(jobId: 5),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Customer\'s budget (per truck)'), findsOneWidget);
    expect(
      find.textContaining('is per truck, not the total for all 20 trucks'),
      findsOneWidget,
    );
  });

  testWidgets('shows the real completion date on a completed job', (
    tester,
  ) async {
    final completedJob = Job(
      id: 5,
      status: 'completed',
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
      agreedPrice: 750000,
      currency: 'TZS',
      assignedCompanyName: 'ABC Logistics',
      assignedTruckRegistration: 'T 123 ABC',
      assignedDriverName: 'Ali Juma',
      proofOfDelivery: null,
      bidsCount: 1,
      completedAt: DateTime(2026, 9, 21, 14, 32),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CompanyJobDetailScreen(
          jobId: 5,
          jobRepository: FakeCompanyJobRepository(
            onShow: (_) async => completedJob,
          ),
          bidRepository: FakeBidRepository(
            onCompanyQuotaRemaining: () async => 3,
          ),
          locationChannel: FakeJobLocationChannel(jobId: 5),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('21 September 2026'), findsOneWidget);
  });

  testWidgets(
    'shows the Rate your experience prompt when reviewable and opens the rating screen',
    (tester) async {
      final reviewableJob = Job(
        id: 5,
        status: 'completed',
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
        agreedPrice: 750000,
        currency: 'TZS',
        assignedCompanyName: null,
        assignedTruckRegistration: null,
        assignedDriverName: null,
        proofOfDelivery: null,
        bidsCount: 1,
        reviewable: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CompanyJobDetailScreen(
            jobId: 5,
            jobRepository: FakeCompanyJobRepository(
              onShow: (_) async => reviewableJob,
            ),
            bidRepository: FakeBidRepository(
              onCompanyQuotaRemaining: () async => 3,
            ),
            locationChannel: FakeJobLocationChannel(jobId: 5),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rate your experience'));
      await tester.pumpAndSettle();

      // transporterRatingCustomer's category labels confirm the direction
      // wired from this (company-facing) screen is correct.
      expect(find.text('Accurate cargo information'), findsOneWidget);
    },
  );

  testWidgets('shows a Follow button for the customer and follows on tap', (
    tester,
  ) async {
    final jobWithCustomer = Job(
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
      customerId: 42,
      customerName: 'Amina Hassan',
      isFollowingCustomer: false,
    );
    int? followedCustomerId;

    await tester.pumpWidget(
      MaterialApp(
        home: CompanyJobDetailScreen(
          jobId: 5,
          jobRepository: FakeCompanyJobRepository(
            onShow: (_) async => jobWithCustomer,
          ),
          bidRepository: FakeBidRepository(
            onCompanyQuotaRemaining: () async => 3,
          ),
          locationChannel: FakeJobLocationChannel(jobId: 5),
          followRepository: FakeFollowRepository(
            onFollow: (id) async {
              followedCustomerId = id;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Amina Hassan'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);

    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();

    expect(followedCustomerId, 42);
    expect(find.text('Following'), findsOneWidget);
  });

  testWidgets(
    'shows Following for an already-followed customer and unfollows on tap',
    (tester) async {
      final jobWithCustomer = Job(
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
        customerId: 42,
        customerName: 'Amina Hassan',
        isFollowingCustomer: true,
      );
      int? unfollowedCustomerId;

      await tester.pumpWidget(
        MaterialApp(
          home: CompanyJobDetailScreen(
            jobId: 5,
            jobRepository: FakeCompanyJobRepository(
              onShow: (_) async => jobWithCustomer,
            ),
            bidRepository: FakeBidRepository(
              onCompanyQuotaRemaining: () async => 3,
            ),
            locationChannel: FakeJobLocationChannel(jobId: 5),
            followRepository: FakeFollowRepository(
              onUnfollow: (id) async {
                unfollowedCustomerId = id;
                return false;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Following'), findsOneWidget);

      await tester.tap(find.text('Following'));
      await tester.pumpAndSettle();

      expect(unfollowedCustomerId, 42);
      expect(find.text('Follow'), findsOneWidget);
    },
  );

  testWidgets(
    'the customer name on an open job is wired to open their public profile',
    (tester) async {
      final jobWithCustomer = Job(
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
        customerId: 42,
        customerName: 'Amina Hassan',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CompanyJobDetailScreen(
            jobId: 5,
            jobRepository: FakeCompanyJobRepository(
              onShow: (_) async => jobWithCustomer,
            ),
            bidRepository: FakeBidRepository(
              onCompanyQuotaRemaining: () async => 3,
            ),
            locationChannel: FakeJobLocationChannel(jobId: 5),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigating for real would hit the live ProfileRepository (no fake
      // injection point at this call site — same as _BidCard's own tap-to-
      // profile link) and hang the test on a real network call, so this
      // verifies the tap target itself is wired rather than following it.
      final inkWell = tester.widget<InkWell>(
        find
            .ancestor(
              of: find.text('Amina Hassan'),
              matching: find.byType(InkWell),
            )
            .first,
      );
      expect(inkWell.onTap, isNotNull);
    },
  );

  testWidgets(
    'the customer name on an active/assigned job is wired to open their public profile',
    (tester) async {
      final activeJob = Job(
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
        agreedPrice: 750000,
        currency: 'TZS',
        assignedCompanyName: null,
        assignedTruckRegistration: 'T 123 ABC',
        assignedDriverName: 'Ali Juma',
        proofOfDelivery: null,
        bidsCount: 0,
        isAssignedToViewer: true,
        customerId: 42,
        customerName: 'Amina Hassan',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CompanyJobDetailScreen(
            jobId: 5,
            jobRepository: FakeCompanyJobRepository(
              onShow: (_) async => activeJob,
            ),
            bidRepository: FakeBidRepository(
              onCompanyQuotaRemaining: () async => 3,
            ),
            assignmentRepository: FakeJobAssignmentRepository(),
            locationChannel: FakeJobLocationChannel(jobId: 5),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final inkWell = tester.widget<InkWell>(
        find
            .ancestor(
              of: find.text('Amina Hassan'),
              matching: find.byType(InkWell),
            )
            .first,
      );
      expect(inkWell.onTap, isNotNull);
    },
  );

  testWidgets('shows no budget row when the job has none', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyJobDetailScreen(
          jobId: 5,
          jobRepository: FakeCompanyJobRepository(
            onShow: (_) async => _openJob,
          ),
          bidRepository: FakeBidRepository(
            onCompanyQuotaRemaining: () async => 3,
          ),
          locationChannel: FakeJobLocationChannel(jobId: 5),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Customer\'s budget'), findsNothing);
  });

  testWidgets('shows the job and remaining bid quota', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyJobDetailScreen(
          jobId: 5,
          jobRepository: FakeCompanyJobRepository(
            onShow: (_) async => _openJob,
          ),
          bidRepository: FakeBidRepository(
            onCompanyQuotaRemaining: () async => 3,
          ),
          locationChannel: FakeJobLocationChannel(jobId: 5),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Dry Van · 40ft'), findsOneWidget);
    expect(find.text('3 bid(s) remaining'), findsOneWidget);
  });

  testWidgets(
    'shows unlimited bids for a Plus company instead of a countdown',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CompanyJobDetailScreen(
            jobId: 5,
            jobRepository: FakeCompanyJobRepository(
              onShow: (_) async => _openJob,
            ),
            bidRepository: FakeBidRepository(
              onCompanyQuotaRemaining: () async => -1,
            ),
            locationChannel: FakeJobLocationChannel(jobId: 5),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unlimited bids (Plus)'), findsOneWidget);
      expect(find.textContaining('bid(s) remaining'), findsNothing);
    },
  );

  testWidgets('places a bid and shows the pending confirmation', (
    tester,
  ) async {
    double? capturedPrice;
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyJobDetailScreen(
          jobId: 5,
          jobRepository: FakeCompanyJobRepository(
            onShow: (_) async => _openJob,
          ),
          bidRepository: FakeBidRepository(
            onCompanyQuotaRemaining: () async => 3,
            onPlace:
                ({
                  required jobId,
                  required price,
                  estimatedPickupTime,
                  note,
                  trucksOffered,
                }) async {
                  capturedPrice = price;
                  return Bid(
                    id: 1,
                    jobId: jobId,
                    price: price,
                    estimatedPickupTime: null,
                    note: note,
                    status: 'pending',
                    isPriority: false,
                    company: const BidCompany(
                      id: 1,
                      name: 'ABC',
                      verified: true,
                      truckCount: 1,
                      gpsAvailable: false,
                      rating: null,
                      ratingCount: 0,
                    ),
                  );
                },
          ),
          locationChannel: FakeJobLocationChannel(jobId: 5),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('bidPriceField')), '750000');
    await tester.tap(find.text('SUBMIT BID'));
    await tester.pumpAndSettle();

    expect(capturedPrice, 750000);
    expect(
      find.text('Bid placed: TZS 750000 — pending review.'),
      findsOneWidget,
    );
  });

  testWidgets('rejects an invalid price without calling the repository', (
    tester,
  ) async {
    var placeCalled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyJobDetailScreen(
          jobId: 5,
          jobRepository: FakeCompanyJobRepository(
            onShow: (_) async => _openJob,
          ),
          bidRepository: FakeBidRepository(
            onCompanyQuotaRemaining: () async => 3,
            onPlace:
                ({
                  required jobId,
                  required price,
                  estimatedPickupTime,
                  note,
                  trucksOffered,
                }) async {
                  placeCalled = true;
                  throw StateError('should not be called');
                },
          ),
          locationChannel: FakeJobLocationChannel(jobId: 5),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('SUBMIT BID'));
    await tester.pump();

    expect(find.text('Enter a valid price.'), findsOneWidget);
    expect(placeCalled, isFalse);
  });

  testWidgets('shows a quota-exceeded message with the reset time', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyJobDetailScreen(
          jobId: 5,
          jobRepository: FakeCompanyJobRepository(
            onShow: (_) async => _openJob,
          ),
          bidRepository: FakeBidRepository(
            onCompanyQuotaRemaining: () async => 1,
            onPlace:
                ({
                  required jobId,
                  required price,
                  estimatedPickupTime,
                  note,
                  trucksOffered,
                }) async {
                  throw ApiException(
                    'Bid limit reached.',
                    body: {'seconds_until_slot_frees': 600},
                  );
                },
          ),
          locationChannel: FakeJobLocationChannel(jobId: 5),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('bidPriceField')), '500000');
    await tester.tap(find.text('SUBMIT BID'));
    await tester.pumpAndSettle();

    expect(
      find.text('Bid limit reached. Try again in 10 min.'),
      findsOneWidget,
    );
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
          bidRepository: FakeBidRepository(
            onCompanyQuotaRemaining: () async => 3,
          ),
          locationChannel: FakeJobLocationChannel(jobId: 5),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('This job is no longer open for bidding.'),
      findsOneWidget,
    );
    expect(find.text('SUBMIT BID'), findsNothing);
  });

  testWidgets(
    'the assigned company sees the assignment section, not the bid form',
    (tester) async {
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
            bidRepository: FakeBidRepository(
              onCompanyQuotaRemaining: () async => 3,
            ),
            locationChannel: FakeJobLocationChannel(jobId: 5),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No truck/driver assigned yet.'), findsOneWidget);
      expect(find.text('Assign truck & driver'), findsOneWidget);
      expect(find.text('SUBMIT BID'), findsNothing);
      expect(
        find.text('This job is no longer open for bidding.'),
        findsNothing,
      );
    },
  );

  Job assignedJobWith({required String status}) => Job(
    id: 5,
    status: status,
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
  );

  testWidgets(
    'while still just assigned (not yet started), shows a Reassign action',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CompanyJobDetailScreen(
            jobId: 5,
            jobRepository: FakeCompanyJobRepository(
              onShow: (_) async => assignedJobWith(status: 'assigned'),
            ),
            bidRepository: FakeBidRepository(
              onCompanyQuotaRemaining: () async => 3,
            ),
            assignmentRepository: FakeJobAssignmentRepository(),
            locationChannel: FakeJobLocationChannel(jobId: 5),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('T 123 ABC'), findsOneWidget);
      expect(find.text('Ali Juma'), findsOneWidget);
      expect(find.text('Reassign truck & driver'), findsOneWidget);
      expect(find.text('View driver link'), findsOneWidget);
    },
  );

  testWidgets(
    'once the job has started, hides the Reassign action but keeps GPS/driver-link visible',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CompanyJobDetailScreen(
            jobId: 5,
            jobRepository: FakeCompanyJobRepository(
              onShow: (_) async => assignedJobWith(status: 'en_route_pickup'),
            ),
            bidRepository: FakeBidRepository(
              onCompanyQuotaRemaining: () async => 3,
            ),
            assignmentRepository: FakeJobAssignmentRepository(),
            locationChannel: FakeJobLocationChannel(jobId: 5),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('T 123 ABC'), findsOneWidget);
      expect(find.text('Ali Juma'), findsOneWidget);
      expect(find.text('Reassign truck & driver'), findsNothing);
      expect(find.textContaining('already underway'), findsOneWidget);
      expect(find.text('View driver link'), findsOneWidget);
      expect(find.text('GPS Tracking Not Available'), findsOneWidget);
    },
  );

  testWidgets(
    'a GPS-connected truck shows live position and updates from a socket push',
    (tester) async {
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
                lastKnownLocation: GpsLocation(
                  lat: -6.8,
                  lng: 39.2,
                  heading: 90,
                  recordedAt: DateTime.now(),
                ),
              ),
            ),
            bidRepository: FakeBidRepository(
              onCompanyQuotaRemaining: () async => 3,
            ),
            assignmentRepository: FakeJobAssignmentRepository(),
            locationChannel: locationChannel,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Live'), findsOneWidget);
      expect(find.text('-6.8000, 39.2000'), findsOneWidget);

      locationChannel.emitLocation({
        'lat': -6.81,
        'lng': 39.21,
        'heading': 95,
        'recorded_at': DateTime.now().toIso8601String(),
      });
      await tester.pump();

      expect(find.text('-6.8100, 39.2100'), findsOneWidget);
    },
  );

  testWidgets(
    'a GPS-lost truck shows the signal-unavailable state with the last known position',
    (tester) async {
      // Phase 10 audit gap: the customer-facing job detail screen already
      // tested this state (job_detail_screen_test.dart); this screen's own
      // GpsStatusCard usage never had the equivalent test, despite showing
      // the identical widget.
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
            bidRepository: FakeBidRepository(
              onCompanyQuotaRemaining: () async => 3,
            ),
            assignmentRepository: FakeJobAssignmentRepository(),
            locationChannel: FakeJobLocationChannel(jobId: 5),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('GPS signal unavailable'), findsOneWidget);
    },
  );

  testWidgets(
    'a company with an award sees its own fleet card while the job stays open',
    (tester) async {
      final splitJob = Job(
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
        trucksNeeded: 20,
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
        bidsCount: 1,
        remainingTrucksNeeded: 12,
        awards: const [
          JobAward(
            id: 9,
            companyId: 1,
            companyName: 'Doc Test Logistics',
            trucksOffered: 8,
            agreedPrice: 400000,
            status: 'assigned',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CompanyJobDetailScreen(
            jobId: 5,
            jobRepository: FakeCompanyJobRepository(
              onShow: (_) async => splitJob,
            ),
            bidRepository: FakeBidRepository(
              onCompanyQuotaRemaining: () async => 3,
            ),
            assignmentRepository: FakeJobAssignmentRepository(),
            locationChannel: FakeJobLocationChannel(jobId: 5),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active Job'), findsOneWidget);
      // _SectionLabel upper-cases its text.
      expect(find.text('YOUR FLEET ON THIS JOB'), findsOneWidget);
      expect(find.text('Your fleet (0/8)'), findsOneWidget);
      expect(find.text('Add truck & driver'), findsOneWidget);
      // No bid form — an awarded company never bids again on this job.
      expect(find.text('SUBMIT BID'), findsNothing);
    },
  );

  Job deliveredJob() => Job(
    id: 5,
    status: 'completed',
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
    agreedPrice: 750000,
    currency: 'TZS',
    assignedCompanyName: 'ABC Logistics',
    assignedTruckRegistration: 'T 123 ABC',
    assignedDriverName: 'Ali Juma',
    proofOfDelivery: null,
    bidsCount: 0,
    isAssignedToViewer: true,
  );

  Job returnLoadSuggestion({double? budgetPrice}) => Job(
    id: 88,
    status: 'open',
    pickupAddress: 'Mbezi Beach',
    pickupLat: -6.701,
    pickupLng: 39.101,
    dropoffAddress: 'Ilemela, Mwanza',
    dropoffLat: -2.5,
    dropoffLng: 32.9,
    containerType: 'Dry Van',
    containerSize: '40ft',
    approxWeightTons: 10,
    cargoDescription: null,
    preferredPickupWindowStart: DateTime(2026, 9, 12, 9),
    customerNotes: null,
    budgetPrice: budgetPrice,
    agreedPrice: null,
    currency: 'TZS',
    assignedCompanyName: null,
    assignedTruckRegistration: null,
    assignedDriverName: null,
    proofOfDelivery: null,
    bidsCount: 0,
  );

  testWidgets(
    'a return-load suggestion with a stated price offers a Claim button',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CompanyJobDetailScreen(
            jobId: 5,
            jobRepository: FakeCompanyJobRepository(
              onShow: (_) async => deliveredJob(),
              onReturnLoadSuggestions: (_) async => [
                returnLoadSuggestion(budgetPrice: 300000),
              ],
            ),
            bidRepository: FakeBidRepository(
              onCompanyQuotaRemaining: () async => 3,
            ),
            locationChannel: FakeJobLocationChannel(jobId: 5),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Claim this load — no bidding'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Claim this load — no bidding'), findsOneWidget);
    },
  );

  testWidgets(
    'a return-load suggestion with no stated price offers no Claim button',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CompanyJobDetailScreen(
            jobId: 5,
            jobRepository: FakeCompanyJobRepository(
              onShow: (_) async => deliveredJob(),
              onReturnLoadSuggestions: (_) async => [returnLoadSuggestion()],
            ),
            bidRepository: FakeBidRepository(
              onCompanyQuotaRemaining: () async => 3,
            ),
            locationChannel: FakeJobLocationChannel(jobId: 5),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.textContaining('Mbezi Beach → Ilemela'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Claim this load — no bidding'), findsNothing);
    },
  );

  testWidgets(
    'claiming a return load calls the repository with both job ids and removes the tile',
    (tester) async {
      int? claimedJobId;
      int? claimedFromJobId;

      await tester.pumpWidget(
        MaterialApp(
          home: CompanyJobDetailScreen(
            jobId: 5,
            jobRepository: FakeCompanyJobRepository(
              onShow: (_) async => deliveredJob(),
              onReturnLoadSuggestions: (_) async => [
                returnLoadSuggestion(budgetPrice: 300000),
              ],
              onClaimReturnLoad: (jobId, {required fromJobId}) async {
                claimedJobId = jobId;
                claimedFromJobId = fromJobId;
                return const Bid(
                  id: 9,
                  jobId: 88,
                  price: 300000,
                  estimatedPickupTime: null,
                  note: null,
                  status: 'pending',
                  isPriority: false,
                  company: BidCompany(
                    id: 1,
                    name: 'ABC Logistics',
                    verified: true,
                    truckCount: 5,
                    gpsAvailable: true,
                    rating: 4.8,
                    ratingCount: 20,
                  ),
                  isReturnLoadClaim: true,
                );
              },
            ),
            bidRepository: FakeBidRepository(
              onCompanyQuotaRemaining: () async => 3,
            ),
            locationChannel: FakeJobLocationChannel(jobId: 5),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Claim this load — no bidding'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Claim this load — no bidding'));
      await tester.pumpAndSettle();

      // Confirmation dialog.
      expect(find.text('Claim this return load?'), findsOneWidget);
      await tester.tap(find.text('Claim'));
      await tester.pumpAndSettle();

      expect(claimedJobId, 88);
      expect(claimedFromJobId, 5);
      expect(find.text('Claim this load — no bidding'), findsNothing);
      expect(find.textContaining('Claimed'), findsOneWidget);
    },
  );
}
