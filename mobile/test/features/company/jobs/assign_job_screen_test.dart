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

final _job = Job(
  id: 7,
  status: 'assigned',
  pickupAddress: 'Kariakoo',
  pickupLat: null,
  pickupLng: null,
  dropoffAddress: 'Mbezi Beach',
  dropoffLat: null,
  dropoffLng: null,
  containerType: 'Dry Van',
  containerSize: '40ft',
  approxWeightTons: null,
  cargoDescription: null,
  preferredPickupWindowStart: DateTime(2026, 9, 10, 9),
  customerNotes: null,
  agreedPrice: 500000,
  currency: 'TZS',
  assignedCompanyName: null,
  assignedTruckRegistration: null,
  assignedDriverName: null,
  proofOfDelivery: null,
  bidsCount: 0,
);

const _idleTruck = Truck(
  id: 1,
  registrationNumber: 'T 123 ABC',
  makeModel: 'Isuzu FRR',
  vehicleType: 'Flatbed',
  capacityTons: 10,
  photoUrls: [],
  verificationStatus: 'approved',
  rejectedReason: null,
  gpsStatus: 'not_connected',
  currentStatus: 'idle',
);

const _busyTruck = Truck(
  id: 2,
  registrationNumber: 'T 999 ZZZ',
  makeModel: 'Man TGS',
  vehicleType: 'Tanker',
  capacityTons: 18,
  photoUrls: [],
  verificationStatus: 'approved',
  rejectedReason: null,
  gpsStatus: 'not_connected',
  currentStatus: 'on_job',
);

const _driver = Driver(id: 1, fullName: 'Ali Juma', phoneNumber: '+255700000000', licenseNumber: null, photoUrl: null, isActive: true);

void main() {
  testWidgets('only idle, approved trucks and active drivers are selectable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AssignJobScreen(
          job: _job,
          truckRepository: FakeTruckRepository(onList: () async => [_idleTruck, _busyTruck]),
          driverRepository: FakeDriverRepository(onList: () async => [_driver]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // A DropdownButtonFormField's items only render into the widget tree
    // once the menu is open — closed, it shows no selection (no
    // initialValue was set).
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();

    expect(find.text('T 123 ABC — Isuzu FRR'), findsOneWidget);
    expect(find.text('T 999 ZZZ — Man TGS'), findsNothing);
  });

  testWidgets('shows a message when there are no idle trucks or active drivers', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AssignJobScreen(
          job: _job,
          truckRepository: FakeTruckRepository(onList: () async => [_busyTruck]),
          driverRepository: FakeDriverRepository(onList: () async => []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No idle, approved trucks available.'), findsOneWidget);
    expect(find.text('No active drivers in your roster.'), findsOneWidget);
  });

  testWidgets('assigning shows the driver link confirmation', (tester) async {
    int? capturedTruckId;
    int? capturedDriverId;
    await tester.pumpWidget(
      MaterialApp(
        home: AssignJobScreen(
          job: _job,
          truckRepository: FakeTruckRepository(onList: () async => [_idleTruck]),
          driverRepository: FakeDriverRepository(onList: () async => [_driver]),
          assignmentRepository: FakeJobAssignmentRepository(
            onAssign: ({required jobId, required truckId, required driverId}) async {
              capturedTruckId = truckId;
              capturedDriverId = driverId;
              return DriverLink(
                url: 'https://cargomotives.test/driver-link/abc123',
                status: 'active',
                expiresAt: DateTime(2026, 9, 20),
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
    await tester.tap(find.text('T 123 ABC — Isuzu FRR').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<int>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ali Juma').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(capturedTruckId, 1);
    expect(capturedDriverId, 1);
    expect(find.text('https://cargomotives.test/driver-link/abc123'), findsOneWidget);
  });
}
