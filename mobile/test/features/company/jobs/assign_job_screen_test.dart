import 'package:cargo_motives/features/company/data/driver_repository.dart';
import 'package:cargo_motives/features/company/data/truck_repository.dart';
import 'package:cargo_motives/features/company/jobs/assign_job_screen.dart';
import 'package:cargo_motives/features/company/jobs/data/job_assignment_repository.dart';
import 'package:cargo_motives/features/jobs/data/job_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_driver_repository.dart';
import '../../../support/fake_job_assignment_repository.dart';
import '../../../support/fake_truck_repository.dart';

const _truck1 = Truck(
  id: 1,
  registrationNumber: 'T 111 AAA',
  makeModel: 'Isuzu FRR',
  vehicleType: 'Flatbed',
  capacityTons: 10,
  photoUrls: [],
  verificationStatus: 'approved',
  rejectedReason: null,
  gpsStatus: 'not_connected',
  currentStatus: 'idle',
);

const _truck2 = Truck(
  id: 2,
  registrationNumber: 'T 222 BBB',
  makeModel: 'Mitsubishi Fuso',
  vehicleType: 'Flatbed',
  capacityTons: 10,
  photoUrls: [],
  verificationStatus: 'approved',
  rejectedReason: null,
  gpsStatus: 'not_connected',
  currentStatus: 'idle',
);

const _driver1 = Driver(id: 1, fullName: 'Ali Juma', phoneNumber: '0700000001', licenseNumber: null, photoUrl: null, isActive: true);

Job _job({required int trucksNeeded}) => Job(
  id: 5,
  status: 'assigned',
  pickupAddress: 'Kariakoo',
  pickupLat: -6.8,
  pickupLng: 39.2,
  dropoffAddress: 'Mbezi Beach',
  dropoffLat: -6.7,
  dropoffLng: 39.1,
  containerType: 'Dry Van',
  containerSize: '40ft',
  trucksNeeded: trucksNeeded,
  approxWeightTons: null,
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
  testWidgets('an ordinary single-truck job only shows Done after assigning', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AssignJobScreen(
          job: _job(trucksNeeded: 1),
          truckRepository: FakeTruckRepository(onList: () async => [_truck1]),
          driverRepository: FakeDriverRepository(onList: () async => [_driver1]),
          assignmentRepository: FakeJobAssignmentRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('T 111 AAA — Isuzu FRR').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<int>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ali Juma').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Add another truck'), findsNothing);
  });

  testWidgets('a multi-truck job shows Add another truck alongside Done', (tester) async {
    int? capturedTruckId;
    await tester.pumpWidget(
      MaterialApp(
        home: AssignJobScreen(
          job: _job(trucksNeeded: 20),
          truckRepository: FakeTruckRepository(onList: () async => [_truck1, _truck2]),
          driverRepository: FakeDriverRepository(onList: () async => [_driver1]),
          assignmentRepository: FakeJobAssignmentRepository(
            onAssign: ({required jobId, required truckId, required driverId}) async {
              capturedTruckId = truckId;
              return DriverLink(
                url: 'https://cargomotives.test/driver-link/tok',
                status: 'active',
                expiresAt: DateTime(2026, 10, 1),
                driverName: 'Ali Juma',
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('T 111 AAA — Isuzu FRR').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<int>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ali Juma').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(capturedTruckId, 1);
    expect(find.text('Add another truck'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('Add another truck resets the form and reloads the truck list', (tester) async {
    var listCallCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AssignJobScreen(
          job: _job(trucksNeeded: 20),
          truckRepository: FakeTruckRepository(
            onList: () async {
              listCallCount++;
              return [_truck1, _truck2];
            },
          ),
          driverRepository: FakeDriverRepository(onList: () async => [_driver1]),
          assignmentRepository: FakeJobAssignmentRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('T 111 AAA — Isuzu FRR').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ali Juma').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    final callsBeforeAddAnother = listCallCount;
    await tester.tap(find.text('Add another truck'));
    await tester.pumpAndSettle();

    expect(listCallCount, callsBeforeAddAnother + 1);
    expect(find.text('Confirm'), findsOneWidget);
  });

  testWidgets('excludes trucks already on the job roster from the dropdown', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AssignJobScreen(
          job: _job(trucksNeeded: 20),
          excludedTruckIds: {1},
          truckRepository: FakeTruckRepository(onList: () async => [_truck1, _truck2]),
          driverRepository: FakeDriverRepository(onList: () async => [_driver1]),
          assignmentRepository: FakeJobAssignmentRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('T 111 AAA — Isuzu FRR'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    expect(find.text('T 222 BBB — Mitsubishi Fuso'), findsOneWidget);
  });
}
