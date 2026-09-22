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

const _onJobTruck = Truck(
  id: 3,
  registrationNumber: 'T 789 QRS',
  makeModel: 'Scania R',
  vehicleType: 'Flatbed',
  capacityTons: 20,
  photoUrls: [],
  verificationStatus: 'approved',
  rejectedReason: null,
  gpsStatus: 'not_connected',
  currentStatus: 'on_job',
);

const _gpsConnectedTruck = Truck(
  id: 5,
  registrationNumber: 'T 555 GPS',
  makeModel: 'Hino 500',
  vehicleType: 'Flatbed',
  capacityTons: 12,
  photoUrls: [],
  verificationStatus: 'approved',
  rejectedReason: null,
  gpsStatus: 'connected',
  currentStatus: 'idle',
);

const _gpsImportedTruck = Truck(
  id: 4,
  registrationNumber: 'T456EFS',
  makeModel: 'Pending real details',
  vehicleType: 'Flatbed',
  capacityTons: 10,
  photoUrls: [],
  verificationStatus: 'approved',
  rejectedReason: null,
  gpsStatus: 'connected',
  currentStatus: 'idle',
  isGpsImported: true,
  gpsProvider: 'tracksolid_pro',
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

  testWidgets('lists trucks with their availability and GPS status', (
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
    expect(find.text('T 456 XYZ'), findsOneWidget);
    // Truck review was removed — every truck reads as available/on a job,
    // never "pending verification" or "rejected".
    expect(find.text('Available'), findsNWidgets(2));
    expect(find.text('Rejected — tap to fix'), findsNothing);
    expect(find.text('Pending verification'), findsNothing);
    expect(find.text('GPS off'), findsNWidgets(2));
  });

  /// Editing is no longer gated on a pending/rejected status, so every
  /// truck opens its own edit form — without this, a normally-registered
  /// truck would have no edit path in the UI at all.
  testWidgets('tapping any truck opens its edit form prefilled', (
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

    expect(find.text('Edit truck'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Registration number'),
      findsOneWidget,
    );
  });

  testWidgets(
    'removing an idle truck after confirming calls delete and refreshes the list',
    (tester) async {
      int? deletedId;
      var trucks = [_approvedTruck];
      await tester.pumpWidget(
        MaterialApp(
          home: TruckListTab(
            repository: FakeTruckRepository(
              onList: () async => trucks,
              onDelete: (id) async {
                deletedId = id;
                trucks = [];
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(deletedId, 1);
      expect(find.text('T 123 ABC'), findsNothing);
    },
  );

  testWidgets('a truck on a job has its remove button disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TruckListTab(
          repository: FakeTruckRepository(onList: () async => [_onJobTruck]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.delete_outline),
        matching: find.byType(IconButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'a GPS-imported truck shows its provider label and an Add details button',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TruckListTab(
            repository: FakeTruckRepository(
              onList: () async => [_gpsImportedTruck],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Imported from Tracksolid Pro'), findsOneWidget);
      expect(find.text('Add details'), findsOneWidget);
    },
  );

  testWidgets(
    'a normally-registered truck shows neither the imported label nor Add details',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TruckListTab(
            repository: FakeTruckRepository(
              onList: () async => [_approvedTruck],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Imported from'), findsNothing);
      expect(find.text('Add details'), findsNothing);
    },
  );

  testWidgets(
    'tapping Add details on a GPS-imported truck opens the registration form prefilled',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TruckListTab(
            repository: FakeTruckRepository(
              onList: () async => [_gpsImportedTruck],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add details'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(TextFormField, 'Registration number'),
        findsOneWidget,
      );
      expect(find.text('T456EFS'), findsOneWidget);
    },
  );

  testWidgets(
    'a GPS-connected truck has its remove button disabled and offers a disconnect action instead',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TruckListTab(
            repository: FakeTruckRepository(
              onList: () async => [_gpsConnectedTruck],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.delete_outline),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.onPressed, isNull);
      expect(button.tooltip, 'Disconnect this truck from GPS before removing it');
      expect(find.text('Disconnect GPS'), findsOneWidget);
    },
  );

  testWidgets(
    'disconnecting GPS after confirming calls the repository and refreshes, enabling delete',
    (tester) async {
      int? disconnectedId;
      var trucks = [_gpsConnectedTruck];
      await tester.pumpWidget(
        MaterialApp(
          home: TruckListTab(
            repository: FakeTruckRepository(
              onList: () async => trucks,
              onDisconnectGps: (id) async {
                disconnectedId = id;
                const disconnected = Truck(
                  id: 5,
                  registrationNumber: 'T 555 GPS',
                  makeModel: 'Hino 500',
                  vehicleType: 'Flatbed',
                  capacityTons: 12,
                  photoUrls: [],
                  verificationStatus: 'approved',
                  rejectedReason: null,
                  gpsStatus: 'not_connected',
                  currentStatus: 'idle',
                );
                trucks = [disconnected];
                return disconnected;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Disconnect GPS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();

      expect(disconnectedId, 5);
      expect(find.text('Disconnect GPS'), findsNothing);
      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.delete_outline),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.onPressed, isNotNull);
    },
  );

  /// Live-discovered on a real phone (a narrower, higher-density screen
  /// than the default test surface masked this): a long make/model
  /// string next to the registration number overflowed the card's Row by
  /// 42px with no way to shrink. The make/model text must truncate
  /// instead of pushing the registration number past the edge.
  testWidgets(
    'a long make/model truncates instead of overflowing the card on a narrow screen',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(320, 640));

      const longTruck = Truck(
        id: 6,
        registrationNumber: 'T 999 ZZZ',
        makeModel: 'Mercedes-Benz Actros 2645 6x4 Tipper',
        vehicleType: 'Tanker',
        capacityTons: 30,
        photoUrls: [],
        verificationStatus: 'approved',
        rejectedReason: null,
        gpsStatus: 'not_connected',
        currentStatus: 'idle',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TruckListTab(
            repository: FakeTruckRepository(
              onList: () async => [longTruck],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A RenderFlex overflow throws during layout, which pumpAndSettle
      // above would have already surfaced as a test failure — this is
      // just the explicit, named assertion of what "no overflow" means.
      expect(tester.takeException(), isNull);
      expect(find.text('T 999 ZZZ'), findsOneWidget);
    },
  );
}
