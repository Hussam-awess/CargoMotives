import 'package:cargo_motives/features/company/jobs/job_list_view.dart';
import 'package:cargo_motives/features/jobs/data/job_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Job _job({int? customerCompletedJobsCount, double? budgetPrice, int bidsCount = 0}) => Job(
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
  budgetPrice: budgetPrice,
  agreedPrice: null,
  currency: 'TZS',
  assignedCompanyName: null,
  assignedTruckRegistration: null,
  assignedDriverName: null,
  proofOfDelivery: null,
  bidsCount: bidsCount,
  customerCompletedJobsCount: customerCompletedJobsCount,
);

void main() {
  testWidgets('shows the customer trust signal for a featured company when the count is present', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JobListView(
            loader: () async => [_job(customerCompletedJobsCount: 4)],
            emptyMessage: 'No jobs',
            showCustomerTrustSignal: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('4 completed shipments on Cargo Motives'), findsOneWidget);
  });

  testWidgets('hides the trust signal for a standard company even when the count is present', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JobListView(loader: () async => [_job(customerCompletedJobsCount: 4)], emptyMessage: 'No jobs'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('completed shipment'), findsNothing);
  });

  testWidgets('hides the trust signal when the count is not populated by the backend', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JobListView(loader: () async => [_job()], emptyMessage: 'No jobs', showCustomerTrustSignal: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('completed shipment'), findsNothing);
  });

  testWidgets('shows the customer\'s budget on an open job when one was given', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JobListView(loader: () async => [_job(budgetPrice: 850000, bidsCount: 3)], emptyMessage: 'No jobs'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('850000'), findsOneWidget);
    expect(find.text('TZS budget'), findsOneWidget);
    // The bid count still shows too, folded into the detail line, not lost.
    expect(find.textContaining('3 bids'), findsOneWidget);
  });

  testWidgets('falls back to the bid count when no budget was given', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JobListView(loader: () async => [_job(bidsCount: 2)], emptyMessage: 'No jobs'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('bids so far'), findsOneWidget);
  });

  testWidgets('pull-to-refresh reloads the list without throwing', (tester) async {
    // Regression test: _refresh() used to reassign _future via
    // `setState(() => _future = future)` — an arrow closure whose value IS
    // the assignment's value (a Future), which Flutter's setState()
    // rejects in debug mode (silently tolerated only in release builds).
    var loadCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JobListView(
            loader: () async {
              loadCount++;
              return loadCount == 1 ? [_job()] : [_job(bidsCount: 5)];
            },
            emptyMessage: 'No jobs',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final refreshIndicator = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
    await refreshIndicator.onRefresh();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(loadCount, 2);
    expect(find.textContaining('5 bids'), findsOneWidget);
  });
}
