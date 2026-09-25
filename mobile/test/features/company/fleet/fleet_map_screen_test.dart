import 'package:cargo_motives/core/map/app_map.dart';
import 'package:cargo_motives/core/network/api_exception.dart';
import 'package:cargo_motives/core/theme/app_theme.dart';
import 'package:cargo_motives/features/company/data/company_repository.dart';
import 'package:cargo_motives/features/company/data/truck_repository.dart';
import 'package:cargo_motives/features/company/fleet/fleet_map_screen.dart';
import 'package:cargo_motives/features/company/settings/company_location_screen.dart';
import 'package:cargo_motives/features/jobs/map_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_company_repository.dart';
import '../../../support/fake_truck_repository.dart';

void main() {
  testWidgets('shows GPS-connected trucks with their last known position', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FleetMapScreen(
          repository: FakeTruckRepository(
            onMap: () async => [
              Truck(
                id: 1,
                registrationNumber: 'T 123 ABC',
                makeModel: 'Isuzu',
                vehicleType: 'Flatbed',
                capacityTons: 10,
                photoUrls: const [],
                verificationStatus: 'approved',
                rejectedReason: null,
                gpsStatus: 'connected',
                currentStatus: 'idle',
                lastKnownLat: -6.8161,
                lastKnownLng: 39.2803,
                lastKnownAt: DateTime.now(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Appears twice now: once in the map marker's own floating label
    // (matching Tracksolid Pro's convention) and once in the bottom
    // sheet's list row.
    expect(find.text('T 123 ABC'), findsWidgets);
    expect(find.textContaining('-6.816, 39.280'), findsOneWidget);
  });

  testWidgets(
    'tapping a truck shows its plate number and GPS-reported driver name',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FleetMapScreen(
            repository: FakeTruckRepository(
              onMap: () async => [
                Truck(
                  id: 1,
                  registrationNumber: 'T 123 ABC',
                  makeModel: 'Isuzu FRR',
                  vehicleType: 'Flatbed',
                  capacityTons: 10,
                  photoUrls: const [],
                  verificationStatus: 'approved',
                  rejectedReason: null,
                  gpsStatus: 'connected',
                  currentStatus: 'idle',
                  lastKnownLat: -6.8161,
                  lastKnownLng: 39.2803,
                  lastKnownAt: DateTime.now(),
                  gpsDriverName: 'JOSEFAT MGOSI',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the list row specifically, not the map marker label — both
      // now show the same plate text since the marker also carries a
      // floating label matching Tracksolid Pro's convention.
      await tester.tap(find.widgetWithText(InkWell, 'T 123 ABC'));
      await tester.pumpAndSettle();

      expect(find.text('Driver'), findsOneWidget);
      // Also appears twice now: once in the map marker's label, once in
      // the opened info sheet.
      expect(find.text('JOSEFAT MGOSI'), findsWidgets);
    },
  );

  testWidgets('a truck with no GPS-reported driver shows the fallback text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FleetMapScreen(
          repository: FakeTruckRepository(
            onMap: () async => [
              Truck(
                id: 1,
                registrationNumber: 'T 456 XYZ',
                makeModel: 'Man TGS',
                vehicleType: 'Tanker',
                capacityTons: 18,
                photoUrls: const [],
                verificationStatus: 'approved',
                rejectedReason: null,
                gpsStatus: 'connected',
                currentStatus: 'idle',
                lastKnownLat: -6.8161,
                lastKnownLng: 39.2803,
                lastKnownAt: DateTime.now(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(InkWell, 'T 456 XYZ'));
    await tester.pumpAndSettle();

    expect(find.text('Driver not reported'), findsOneWidget);
  });

  testWidgets('shows an empty state when nothing is GPS-connected', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FleetMapScreen(
          repository: FakeTruckRepository(onMap: () async => []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No GPS-connected trucks yet.'), findsOneWidget);
  });

  testWidgets(
    'shows a retry option on a load failure — the fleet map is no longer Plus-gated',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FleetMapScreen(
            repository: FakeTruckRepository(
              onMap: () async =>
                  throw ApiException('Server error', statusCode: 500),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load your fleet map.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    },
  );

  testWidgets(
    'marks a moving truck green and a stationary one red, regardless of job status',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FleetMapScreen(
            repository: FakeTruckRepository(
              onMap: () async => [
                Truck(
                  id: 1,
                  registrationNumber: 'T 111 ONL',
                  makeModel: 'Isuzu',
                  vehicleType: 'Flatbed',
                  capacityTons: 10,
                  photoUrls: const [],
                  verificationStatus: 'approved',
                  rejectedReason: null,
                  gpsStatus: 'connected',
                  // On a job — must still read as moving/green, not blue.
                  currentStatus: 'on_job',
                  lastKnownLat: -6.8161,
                  lastKnownLng: 39.2803,
                  lastKnownAt: DateTime.now(),
                  gpsOnline: true,
                  gpsMoving: true,
                ),
                Truck(
                  id: 2,
                  registrationNumber: 'T 222 OFF',
                  makeModel: 'Man TGS',
                  vehicleType: 'Tanker',
                  capacityTons: 18,
                  photoUrls: const [],
                  verificationStatus: 'approved',
                  rejectedReason: null,
                  gpsStatus: 'connected',
                  currentStatus: 'idle',
                  lastKnownLat: -6.82,
                  lastKnownLng: 39.28,
                  lastKnownAt: DateTime.now().subtract(
                    const Duration(hours: 2),
                  ),
                  gpsOnline: false,
                  gpsMoving: false,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final markers = tester
          .widgetList<TruckFleetMarker>(find.byType(TruckFleetMarker))
          .toList();
      expect(markers, hasLength(2));
      expect(markers[0].color, AppColors.statusLive);
      expect(markers[1].color, AppColors.statusError);
    },
  );

  testWidgets(
    'a truck reporting fine but parked for a while shows Stationary, not Moving',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FleetMapScreen(
            repository: FakeTruckRepository(
              onMap: () async => [
                Truck(
                  id: 1,
                  registrationNumber: 'T 999 PRK',
                  makeModel: 'Isuzu',
                  vehicleType: 'Flatbed',
                  capacityTons: 10,
                  photoUrls: const [],
                  verificationStatus: 'approved',
                  rejectedReason: null,
                  gpsStatus: 'connected',
                  currentStatus: 'idle',
                  lastKnownLat: -6.8161,
                  lastKnownLng: 39.2803,
                  lastKnownAt: DateTime.now(),
                  gpsOnline: true,
                  gpsMoving: false,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Stationary'), findsOneWidget);
      expect(find.text('Moving'), findsNothing);
    },
  );

  testWidgets(
    'the fleet map refreshes itself periodically without a loading spinner',
    (tester) async {
      var mapCallCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: FleetMapScreen(
            repository: FakeTruckRepository(
              onMap: () async {
                mapCallCount++;
                return [
                  Truck(
                    id: 1,
                    registrationNumber: 'T 123 ABC',
                    makeModel: 'Isuzu',
                    vehicleType: 'Flatbed',
                    capacityTons: 10,
                    photoUrls: const [],
                    verificationStatus: 'approved',
                    rejectedReason: null,
                    gpsStatus: 'connected',
                    currentStatus: 'idle',
                    lastKnownLat: -6.8161,
                    lastKnownLng: 39.2803,
                    lastKnownAt: DateTime.now(),
                  ),
                ];
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(mapCallCount, 1);

      await tester.pump(const Duration(seconds: 12));
      expect(mapCallCount, 2);
      // No spinner interrupts the already-loaded map on a background tick.
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pump(const Duration(seconds: 12));
      expect(mapCallCount, 3);
    },
  );

  /// The whole point of this feature — a company should be able to see
  /// exactly how stale/fresh a moving truck's marker is, not just trust
  /// that a refresh is silently happening somewhere.
  testWidgets(
    'shows a visible countdown to the next refresh, ticking down every second',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FleetMapScreen(
            repository: FakeTruckRepository(onMap: () async => const []),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Live · 12 s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Live · 11 s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Live · 6 s'), findsOneWidget);

      // Ticks down to the refresh, then resets to a fresh 12s countdown.
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Live · 12 s'), findsOneWidget);
    },
  );

  testWidgets(
    'the bottom sheet can actually be dragged to reveal more of the map',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FleetMapScreen(
            repository: FakeTruckRepository(
              onMap: () async => [
                Truck(
                  id: 1,
                  registrationNumber: 'T 123 ABC',
                  makeModel: 'Isuzu',
                  vehicleType: 'Flatbed',
                  capacityTons: 10,
                  photoUrls: const [],
                  verificationStatus: 'approved',
                  rejectedReason: null,
                  gpsStatus: 'connected',
                  currentStatus: 'idle',
                  lastKnownLat: -6.8161,
                  lastKnownLng: 39.2803,
                  lastKnownAt: DateTime.now(),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sheetContent = find.byKey(const Key('fleetMapSheetContent'));
      final heightBefore = tester.getSize(sheetContent).height;

      // Drag the handle down toward the sheet's minChildSize — the old
      // implementation had no drag behavior at all behind its handle, so
      // this would previously leave the sheet's height completely
      // unchanged no matter how far it was dragged.
      await tester.drag(
        find.byKey(const Key('fleetMapSheetContent')),
        const Offset(0, 300),
      );
      await tester.pumpAndSettle();

      final heightAfter = tester.getSize(sheetContent).height;
      expect(heightAfter, lessThan(heightBefore));

      // And back up again — confirms the sheet isn't just collapsible one
      // way, it genuinely tracks the drag in both directions.
      await tester.drag(
        find.byKey(const Key('fleetMapSheetContent')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      final heightAfterExpand = tester.getSize(sheetContent).height;
      expect(heightAfterExpand, greaterThan(heightAfter));
    },
  );

  /// The company's own "home base" pin, surfaced directly on the map a
  /// transporter opens most often, rather than only being reachable from
  /// a settings sub-screen.
  testWidgets(
    'shows a company location marker when the company has set a home base pin',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FleetMapScreen(
            repository: FakeTruckRepository(onMap: () async => const []),
            companyRepository: FakeCompanyRepository(
              onGetStatus: () async => const CompanyVerification(
                status: 'approved',
                rejectedReason: null,
                companyName: 'ABC Logistics',
                physicalLat: -6.8161,
                physicalLng: 39.2803,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppMapPin), findsOneWidget);
    },
  );

  testWidgets(
    'the home button opens the company location screen even before a pin is set',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FleetMapScreen(
            repository: FakeTruckRepository(onMap: () async => const []),
            companyRepository: FakeCompanyRepository(
              onGetStatus: () async => const CompanyVerification(
                status: 'approved',
                rejectedReason: null,
                companyName: 'ABC Logistics',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No pin yet, so no marker on the map.
      expect(find.byType(AppMapPin), findsNothing);

      await tester.tap(find.byIcon(Icons.home));
      await tester.pumpAndSettle();

      expect(find.byType(CompanyLocationScreen), findsOneWidget);
    },
  );
}
