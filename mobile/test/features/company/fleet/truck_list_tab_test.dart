import 'package:cargo_motives/features/company/data/truck_repository.dart';
import 'package:cargo_motives/features/company/fleet/truck_list_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_truck_repository.dart';

const _approvedTruck = Truck(
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

const _rejectedTruck = Truck(
  id: 2,
  registrationNumber: 'T 456 XYZ',
  makeModel: 'Man TGS',
  vehicleType: 'Tanker',
  capacityTons: 18,
  photoUrls: [],
  verificationStatus: 'rejected',
  rejectedReason: 'Insurance expired.',
  gpsStatus: 'not_connected',
  currentStatus: 'idle',
);

void main() {
  testWidgets('shows an empty state when there are no trucks', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TruckListTab(
          repository: FakeTruckRepository(onList: () async => []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No trucks yet. Tap + to register your first one.'),
      findsOneWidget,
    );
  });

  testWidgets('lists trucks with their verification and GPS status', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TruckListTab(
          repository: FakeTruckRepository(
            onList: () async => [_approvedTruck, _rejectedTruck],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('T 123 ABC'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('T 456 XYZ'), findsOneWidget);
    expect(find.text('Rejected — tap to fix'), findsOneWidget);
    expect(find.text('GPS Tracking Not Available'), findsNWidgets(2));
  });

  testWidgets('tapping a rejected truck opens the resubmit form prefilled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TruckListTab(
          repository: FakeTruckRepository(onList: () async => [_rejectedTruck]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('T 456 XYZ'));
    await tester.pumpAndSettle();

    expect(find.text('Resubmit truck'), findsOneWidget);
    expect(find.text('Insurance expired.'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Registration number'),
      findsOneWidget,
    );
  });

  testWidgets('tapping an approved truck does nothing (not editable)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TruckListTab(
          repository: FakeTruckRepository(onList: () async => [_approvedTruck]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('T 123 ABC'));
    await tester.pumpAndSettle();

    expect(find.text('Resubmit truck'), findsNothing);
    expect(find.text('T 123 ABC'), findsOneWidget);
  });
}
