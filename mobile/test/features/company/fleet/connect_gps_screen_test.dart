import 'package:cargo_motives/core/network/api_exception.dart';
import 'package:cargo_motives/features/company/data/gps_repository.dart';
import 'package:cargo_motives/features/company/data/truck_repository.dart';
import 'package:cargo_motives/features/company/fleet/connect_gps_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_gps_repository.dart';
import '../../../support/fake_truck_repository.dart';

const _truckOne = Truck(
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

const _truckTwo = Truck(
  id: 2,
  registrationNumber: 'T 456 XYZ',
  makeModel: 'Man TGS',
  vehicleType: 'Tanker',
  capacityTons: 18,
  photoUrls: [],
  verificationStatus: 'approved',
  rejectedReason: null,
  gpsStatus: 'not_connected',
  currentStatus: 'idle',
);

void main() {
  testWidgets('requires a token before connecting', (tester) async {
    var connectCalled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ConnectGpsScreen(
          gpsRepository: FakeGpsRepository(
            onConnect: ({required provider, required accessToken}) async {
              connectCalled = true;
              throw StateError('should not be called');
            },
          ),
          truckRepository: FakeTruckRepository(),
        ),
      ),
    );

    await tester.tap(find.text('Connect'));
    await tester.pump();

    expect(find.text('Enter your Wialon API token.'), findsOneWidget);
    expect(connectCalled, isFalse);
  });

  testWidgets('selecting a different provider changes the token label and the connect() call', (tester) async {
    String? capturedProvider;
    await tester.pumpWidget(
      MaterialApp(
        home: ConnectGpsScreen(
          gpsRepository: FakeGpsRepository(
            onConnect: ({required provider, required accessToken}) async {
              capturedProvider = provider;
              return (
                connection: GpsConnectionSummary(
                  id: 1,
                  provider: provider,
                  status: 'connected',
                  connectedAt: DateTime.now(),
                  lastSyncedAt: null,
                ),
                units: const <GpsUnitCandidate>[],
              );
            },
          ),
          truckRepository: FakeTruckRepository(),
        ),
      ),
    );

    expect(find.text('Wialon API token'), findsOneWidget);

    await tester.tap(find.text('Traccar'));
    await tester.pump();

    expect(find.text('Traccar API token'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'a-real-token');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(capturedProvider, 'traccar');
  });

  testWidgets('connecting shows the returned units with a pre-suggested match', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConnectGpsScreen(
          gpsRepository: FakeGpsRepository(
            onConnect: ({required provider, required accessToken}) async => (
              connection: GpsConnectionSummary(
                id: 1,
                provider: 'wialon',
                status: 'connected',
                connectedAt: DateTime.now(),
                lastSyncedAt: null,
              ),
              units: const [
                GpsUnitCandidate(unitId: 'unit-1', name: 'T123ABC', hasPosition: true, suggestedTruckId: 1),
                GpsUnitCandidate(unitId: 'unit-2', name: 'Unknown Vehicle', hasPosition: false, suggestedTruckId: null),
              ],
            ),
          ),
          truckRepository: FakeTruckRepository(onList: () async => [_truckOne, _truckTwo]),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'a-real-token');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(find.text('✓ Wialon connected'), findsOneWidget);
    expect(find.text('We found 2 vehicle(s)'), findsOneWidget);
    expect(find.text('T123ABC'), findsOneWidget);
    expect(find.text('No position reported yet'), findsOneWidget);
    // The suggested match pre-fills the dropdown for unit-1.
    expect(find.text('T 123 ABC'), findsOneWidget);
  });

  testWidgets('an invalid token surfaces the server error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConnectGpsScreen(
          gpsRepository: FakeGpsRepository(
            onConnect: ({required provider, required accessToken}) async => throw ApiException(
              'Invalid token.',
              fieldErrors: {
                'access_token': ['Invalid token.'],
              },
            ),
          ),
          truckRepository: FakeTruckRepository(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'bad-token');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid token.'), findsOneWidget);
  });

  testWidgets('importing links the confirmed matches and shows a summary', (tester) async {
    Map<String, int>? capturedMatches;
    await tester.pumpWidget(
      MaterialApp(
        home: ConnectGpsScreen(
          gpsRepository: FakeGpsRepository(
            onConnect: ({required provider, required accessToken}) async => (
              connection: GpsConnectionSummary(
                id: 7,
                provider: 'wialon',
                status: 'connected',
                connectedAt: DateTime.now(),
                lastSyncedAt: null,
              ),
              units: const [GpsUnitCandidate(unitId: 'unit-1', name: 'T123ABC', hasPosition: true, suggestedTruckId: 1)],
            ),
            onImport: ({required connectionId, required unitIdToTruckId}) async {
              capturedMatches = unitIdToTruckId;
              return [_truckOne];
            },
          ),
          truckRepository: FakeTruckRepository(onList: () async => [_truckOne]),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'a-real-token');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import selected vehicles'));
    await tester.pumpAndSettle();

    expect(capturedMatches, {'unit-1': 1});
    expect(find.text('1 truck(s) connected'), findsOneWidget);
    expect(find.text('T 123 ABC'), findsOneWidget);
  });
}
