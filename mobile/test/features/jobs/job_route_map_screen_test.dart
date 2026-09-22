import 'package:cargo_motives/core/map/routing_service.dart';
import 'package:cargo_motives/features/jobs/data/job_repository.dart';
import 'package:cargo_motives/features/jobs/job_route_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

class _FakeRoutingService extends RoutingService {
  _FakeRoutingService({this.result});

  final RouteResult? result;

  @override
  Future<RouteResult?> route(LatLng from, LatLng to) async => result;
}

Job _job({
  double? pickupLat = -6.8161,
  double? pickupLng = 39.2803,
  double? dropoffLat = -6.7,
  double? dropoffLng = 39.2,
}) => Job(
  id: 5,
  status: 'open',
  pickupAddress: 'Kariakoo, Dar es Salaam',
  pickupLat: pickupLat,
  pickupLng: pickupLng,
  dropoffAddress: 'Mbezi Beach, Dar es Salaam',
  dropoffLat: dropoffLat,
  dropoffLng: dropoffLng,
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
);

void main() {
  testWidgets(
    'shows both addresses and the real route distance once routing succeeds',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: JobRouteMapScreen(
            job: _job(),
            routingService: _FakeRoutingService(
              result: const RouteResult(
                points: [LatLng(-6.8161, 39.2803), LatLng(-6.7, 39.2)],
                distanceKm: 12.5,
                durationMinutes: 22,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kariakoo, Dar es Salaam'), findsOneWidget);
      expect(find.text('Mbezi Beach, Dar es Salaam'), findsOneWidget);
      expect(find.text('13 km'), findsOneWidget);
      expect(find.text('22 min'), findsOneWidget);
    },
  );

  testWidgets('falls back to the straight-line distance when routing fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: JobRouteMapScreen(
          job: _job(),
          routingService: _FakeRoutingService(result: null),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No real route, so no distance/duration badge from RoutingService —
    // just the always-available haversine estimate.
    expect(find.text('Est. driving time'), findsNothing);
    expect(find.textContaining('km'), findsOneWidget);
  });

  testWidgets('shows a fallback message when the job has no coordinates', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: JobRouteMapScreen(
          job: _job(pickupLat: null, pickupLng: null),
          routingService: _FakeRoutingService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Route not available for this job.'), findsOneWidget);
  });

  /// The reported bug: the bottom info bar looked static and permanently
  /// blocked a fixed chunk of the map, with no drag behavior behind it at
  /// all — same bug already fixed on LiveGpsTrackingScreen/FleetMapScreen.
  testWidgets(
    'the bottom info sheet can actually be dragged to reveal more of the map',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: JobRouteMapScreen(
            job: _job(),
            routingService: _FakeRoutingService(
              result: const RouteResult(
                points: [LatLng(-6.8161, 39.2803), LatLng(-6.7, 39.2)],
                distanceKm: 12.5,
                durationMinutes: 22,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sheetContent = find.byKey(const Key('routeMapSheetContent'));
      final heightBefore = tester.getSize(sheetContent).height;

      await tester.drag(sheetContent, const Offset(0, 200));
      await tester.pumpAndSettle();
      final heightAfter = tester.getSize(sheetContent).height;
      expect(heightAfter, lessThan(heightBefore));

      // And back up again — confirms it genuinely tracks the drag in both
      // directions, not just a one-way collapse.
      await tester.drag(sheetContent, const Offset(0, -200));
      await tester.pumpAndSettle();
      final heightAfterExpand = tester.getSize(sheetContent).height;
      expect(heightAfterExpand, greaterThan(heightAfter));
    },
  );
}
