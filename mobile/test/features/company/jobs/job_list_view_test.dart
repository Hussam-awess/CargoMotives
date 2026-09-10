import 'package:cargo_motives/features/company/jobs/job_list_view.dart';
import 'package:cargo_motives/features/jobs/data/job_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Job _job({int? customerCompletedJobsCount}) => Job(
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
}
