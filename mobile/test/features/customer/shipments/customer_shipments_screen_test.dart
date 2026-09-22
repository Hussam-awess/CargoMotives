import 'package:cargo_motives/features/auth/data/auth_repository.dart';
import 'package:cargo_motives/features/customer/shipments/customer_shipments_screen.dart';
import 'package:cargo_motives/features/jobs/data/job_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_job_repository.dart';

Job _job({required String status, DateTime? completedAt, int? jobViewsCount}) {
  return Job(
    id: 19,
    status: status,
    pickupAddress: 'Tegeta',
    pickupLat: -6.7,
    pickupLng: 39.2,
    dropoffAddress: 'Kigamboni',
    dropoffLat: -6.8,
    dropoffLng: 39.3,
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
    completedAt: completedAt,
    jobViewsCount: jobViewsCount,
  );
}

void main() {
  testWidgets('shows the real completion date on a completed shipment', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerShipmentsScreen(
          repository: FakeJobRepository(
            onList: () async => [
              _job(
                status: 'completed',
                completedAt: DateTime(2026, 9, 21, 14, 32),
              ),
            ],
          ),
          authRepository: FakeAuthRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Completed on 21 September 2026'), findsOneWidget);
  });

  testWidgets('shows no completion date for a shipment still in progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerShipmentsScreen(
          repository: FakeJobRepository(
            onList: () async => [_job(status: 'in_transit')],
          ),
          authRepository: FakeAuthRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Completed on'), findsNothing);
  });

  testWidgets('a Plus customer sees the job-views eye badge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerShipmentsScreen(
          repository: FakeJobRepository(
            onList: () async => [_job(status: 'open', jobViewsCount: 3)],
          ),
          authRepository: FakeAuthRepository(
            onMe: () async => const UserProfile(
              fullName: 'Amina',
              companyName: null,
              isFeatured: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('a non-Plus customer does not see the job-views eye badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerShipmentsScreen(
          repository: FakeJobRepository(
            onList: () async => [_job(status: 'open', jobViewsCount: 3)],
          ),
          authRepository: FakeAuthRepository(
            onMe: () async => const UserProfile(
              fullName: 'Amina',
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
}
