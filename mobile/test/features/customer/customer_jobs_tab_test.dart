import 'package:cargo_motives/features/customer/customer_jobs_tab.dart';
import 'package:cargo_motives/features/jobs/data/job_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_job_repository.dart';

final _job = Job(
  id: 1,
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
  bidsCount: 0,
);

void main() {
  testWidgets('shows an empty state when there are no jobs', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CustomerJobsTab(repository: FakeJobRepository(onList: () async => []))),
    );
    await tester.pumpAndSettle();

    expect(find.text('No jobs yet. Tap Post to create one.'), findsOneWidget);
  });

  testWidgets('lists jobs with their status', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CustomerJobsTab(repository: FakeJobRepository(onList: () async => [_job]))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dry Van · 40ft'), findsOneWidget);
    expect(find.text('Kariakoo → Mbezi Beach'), findsOneWidget);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('shows an error state with a retry button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CustomerJobsTab(repository: FakeJobRepository(onList: () async => throw StateError('boom')))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load your jobs.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
