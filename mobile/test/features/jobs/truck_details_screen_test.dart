import 'package:cargo_motives/features/jobs/data/bid_repository.dart';
import 'package:cargo_motives/features/jobs/data/job_repository.dart';
import 'package:cargo_motives/features/jobs/truck_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _job = Job(
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

void main() {
  testWidgets('shows a FEATURED badge for a priority bid', (tester) async {
    const bid = Bid(
      id: 1,
      jobId: 10,
      price: 750000,
      estimatedPickupTime: null,
      note: null,
      status: 'pending',
      isPriority: true,
      company: _company,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TruckDetailsScreen(job: _job, bid: bid, onAccept: () {}),
      ),
    );

    expect(find.text('FEATURED'), findsOneWidget);
  });

  testWidgets('shows no FEATURED badge for a standard bid', (tester) async {
    const bid = Bid(
      id: 1,
      jobId: 10,
      price: 750000,
      estimatedPickupTime: null,
      note: null,
      status: 'pending',
      isPriority: false,
      company: _company,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TruckDetailsScreen(job: _job, bid: bid, onAccept: () {}),
      ),
    );

    expect(find.text('FEATURED'), findsNothing);
  });
}
