import 'package:cargo_motives/features/company/data/gps_repository.dart';
import 'package:cargo_motives/features/company/fleet/fleet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_driver_repository.dart';
import '../../../support/fake_gps_repository.dart';
import '../../../support/fake_truck_repository.dart';

void main() {
  testWidgets('shows "Connect GPS" when nothing is connected yet', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FleetScreen(
          truckRepository: FakeTruckRepository(),
          driverRepository: FakeDriverRepository(),
          gpsRepository: FakeGpsRepository(onList: () async => []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Connect GPS'), findsOneWidget);
    expect(find.byTooltip('Disconnect GPS'), findsNothing);
  });

  testWidgets('shows "Disconnect GPS" once a connection is active', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FleetScreen(
          truckRepository: FakeTruckRepository(),
          driverRepository: FakeDriverRepository(),
          gpsRepository: FakeGpsRepository(
            onList: () async => [
              GpsConnectionSummary(
                id: 4,
                provider: 'tracksolid_pro',
                status: 'connected',
                connectedAt: DateTime.now(),
                lastSyncedAt: null,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Disconnect GPS'), findsOneWidget);
    expect(find.byTooltip('Connect GPS'), findsNothing);
  });

  testWidgets(
    'tapping Disconnect asks for confirmation, then actually disconnects',
    (tester) async {
      int? disconnectedId;
      var isConnected = true;
      await tester.pumpWidget(
        MaterialApp(
          home: FleetScreen(
            truckRepository: FakeTruckRepository(),
            driverRepository: FakeDriverRepository(),
            gpsRepository: FakeGpsRepository(
              onList: () async => isConnected
                  ? [
                      GpsConnectionSummary(
                        id: 4,
                        provider: 'tracksolid_pro',
                        status: 'connected',
                        connectedAt: DateTime.now(),
                        lastSyncedAt: null,
                      ),
                    ]
                  : [],
              onDisconnect: (id) async {
                disconnectedId = id;
                isConnected = false;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Disconnect GPS'));
      await tester.pumpAndSettle();

      expect(find.text('Disconnect GPS?'), findsOneWidget);

      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();

      expect(disconnectedId, 4);
      expect(find.byTooltip('Connect GPS'), findsOneWidget);
    },
  );

  testWidgets(
    'cancelling the disconnect dialog leaves the connection untouched',
    (tester) async {
      var disconnectCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: FleetScreen(
            truckRepository: FakeTruckRepository(),
            driverRepository: FakeDriverRepository(),
            gpsRepository: FakeGpsRepository(
              onList: () async => [
                GpsConnectionSummary(
                  id: 4,
                  provider: 'tracksolid_pro',
                  status: 'connected',
                  connectedAt: DateTime.now(),
                  lastSyncedAt: null,
                ),
              ],
              onDisconnect: (id) async => disconnectCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Disconnect GPS'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(disconnectCalled, isFalse);
      expect(find.byTooltip('Disconnect GPS'), findsOneWidget);
    },
  );
}
