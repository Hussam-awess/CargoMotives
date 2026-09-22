import 'package:cargo_motives/core/map/app_map.dart';
import 'package:cargo_motives/core/map/routing_service.dart';
import 'package:cargo_motives/core/theme/app_theme.dart';
import 'package:cargo_motives/features/jobs/data/job_repository.dart';
import 'package:cargo_motives/features/jobs/live_gps_tracking_screen.dart';
import 'package:cargo_motives/features/jobs/map_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

class _FakeRoutingService extends RoutingService {
  _FakeRoutingService({this.result});

  final RouteResult? result;

  @override
  Future<RouteResult?> route(LatLng from, LatLng to) async => result;
}

Job _job({
  String status = 'in_transit',
  GpsLocation? lastKnownLocation,
  bool gpsTrackingActive = false,
  String gpsSignalStatus = 'not_applicable',
  String? assignedTruckRegistration,
  String? assignedDriverName,
}) => Job(
  id: 19,
  status: status,
  pickupAddress: 'Tegeta, Dar es Salaam',
  pickupLat: -6.7,
  pickupLng: 39.2,
  dropoffAddress: 'Kigamboni, Dar es Salaam',
  dropoffLat: -6.85,
  dropoffLng: 39.29,
  containerType: 'Reefer',
  containerSize: '40ft',
  approxWeightTons: 12,
  cargoDescription: null,
  preferredPickupWindowStart: DateTime(2026, 9, 11, 9, 11),
  customerNotes: null,
  agreedPrice: null,
  currency: 'TZS',
  assignedCompanyName: null,
  assignedTruckRegistration: assignedTruckRegistration,
  assignedDriverName: assignedDriverName,
  proofOfDelivery: null,
  bidsCount: 0,
  lastKnownLocation: lastKnownLocation,
  gpsTrackingActive: gpsTrackingActive,
  gpsSignalStatus: gpsSignalStatus,
);

void main() {
  testWidgets(
    'the map, back button and status chip all render above the bottom info sheet',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LiveGpsTrackingScreen(
            job: _job(),
            onRefresh: () async => _job(),
            routingService: _FakeRoutingService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Regression test for a bug where the bottom info sheet's Column (missing
      // `mainAxisSize: MainAxisSize.min`) defaulted to MainAxisSize.max and
      // expanded to cover the entire screen, hiding everything behind it.
      expect(find.byType(AppMap), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('GPS signal unavailable'), findsOneWidget);

      // The visible sheet's own content, not the outer DraggableScrollableSheet
      // — that outer widget spans the full stack (it needs the whole area for
      // drag detection), so measuring it would always report the full screen
      // height regardless of how much of the sheet is actually showing.
      final sheetSize = tester.getSize(
        find.byKey(const Key('trackingInfoSheetContent')),
      );
      final screenSize =
          tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(sheetSize.height, lessThan(screenSize.height * 0.6));
    },
  );

  /// The reported bug: the info sheet's handle looked draggable but had no
  /// drag behavior behind it at all, permanently blocking a fixed chunk of
  /// the map no matter how far a transporter tried to drag it down.
  testWidgets(
    'the bottom info sheet can actually be dragged to reveal more of the map',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LiveGpsTrackingScreen(
            job: _job(),
            onRefresh: () async => _job(),
            routingService: _FakeRoutingService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sheetContent = find.byKey(const Key('trackingInfoSheetContent'));
      final heightBefore = tester.getSize(sheetContent).height;

      await tester.drag(sheetContent, const Offset(0, 300));
      await tester.pumpAndSettle();
      final heightAfter = tester.getSize(sheetContent).height;
      expect(heightAfter, lessThan(heightBefore));

      // And back up again — confirms it genuinely tracks the drag in both
      // directions, not just a one-way collapse.
      await tester.drag(sheetContent, const Offset(0, -300));
      await tester.pumpAndSettle();
      final heightAfterExpand = tester.getSize(sheetContent).height;
      expect(heightAfterExpand, greaterThan(heightAfter));
    },
  );

  testWidgets('shows speed and ETA once the truck is live and moving', (
    tester,
  ) async {
    final job = _job(
      lastKnownLocation: GpsLocation(
        lat: -6.75,
        lng: 39.25,
        heading: 90,
        recordedAt: DateTime.now(),
        speedKmh: 60,
      ),
      gpsTrackingActive: true,
      gpsSignalStatus: 'ok',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LiveGpsTrackingScreen(
          job: job,
          onRefresh: () async => job,
          routingService: _FakeRoutingService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('60 km/h'), findsOneWidget);
    expect(find.textContaining('ETA'), findsOneWidget);
  });

  testWidgets('hides ETA when the truck is reported stationary', (
    tester,
  ) async {
    final job = _job(
      lastKnownLocation: GpsLocation(
        lat: -6.75,
        lng: 39.25,
        heading: 90,
        recordedAt: DateTime.now(),
        speedKmh: 0,
      ),
      gpsTrackingActive: true,
      gpsSignalStatus: 'ok',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LiveGpsTrackingScreen(
          job: job,
          onRefresh: () async => job,
          routingService: _FakeRoutingService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The real (zero) speed is still shown — only the ETA, which would be
    // meaningless divided by ~0, is hidden.
    expect(find.text('0 km/h'), findsOneWidget);
    expect(find.textContaining('ETA'), findsNothing);
  });

  testWidgets('tapping the back button pops the route', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LiveGpsTrackingScreen(
                      job: _job(),
                      onRefresh: () async => _job(),
                      routingService: _FakeRoutingService(),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(LiveGpsTrackingScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(LiveGpsTrackingScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  /// The map used to show only three raw pins with nothing connecting
  /// them — this is the actual "show the route" feature request.
  testWidgets(
    'draws a route polyline to the current waypoint once routing resolves',
    (tester) async {
      final job = _job(
        status: 'in_transit',
        lastKnownLocation: GpsLocation(
          lat: -6.8,
          lng: 39.22,
          heading: 90,
          recordedAt: DateTime.now(),
          speedKmh: 40,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LiveGpsTrackingScreen(
            job: job,
            onRefresh: () async => job,
            routingService: _FakeRoutingService(
              result: const RouteResult(
                points: [LatLng(-6.8, 39.22), LatLng(-6.85, 39.29)],
                distanceKm: 9,
                durationMinutes: 15,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PolylineLayer), findsOneWidget);
    },
  );

  testWidgets('draws no polyline when there is no truck position yet', (
    tester,
  ) async {
    final job = _job(lastKnownLocation: null);

    await tester.pumpWidget(
      MaterialApp(
        home: LiveGpsTrackingScreen(
          job: job,
          onRefresh: () async => job,
          // A non-null result the screen must never draw, since there's no
          // truck position to route from in the first place.
          routingService: _FakeRoutingService(
            result: const RouteResult(
              points: [LatLng(-6.8, 39.22), LatLng(-6.85, 39.29)],
              distanceKm: 9,
              durationMinutes: 15,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // AppMap only inserts a PolylineLayer into the map's children at all
    // when its polylines list is non-empty — there's nothing to route
    // from without a truck position, so none should exist here.
    expect(find.byType(PolylineLayer), findsNothing);
  });

  /// The other real gap this fixes: "Live GPS Tracking" used to render a
  /// static snapshot of whatever Job was passed at navigation time and
  /// never update again while the screen stayed open.
  testWidgets('refreshes itself periodically without a loading spinner', (
    tester,
  ) async {
    var refreshCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LiveGpsTrackingScreen(
          job: _job(),
          onRefresh: () async {
            refreshCount++;
            return _job();
          },
          routingService: _FakeRoutingService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(refreshCount, 0); // the initial job comes from the constructor.

    await tester.pump(const Duration(seconds: 12));
    expect(refreshCount, 1);
    // No spinner interrupts the already-loaded map on a background tick.
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pump(const Duration(seconds: 12));
    expect(refreshCount, 2);
  });

  /// The whole point of this feature — a customer should be able to see
  /// exactly how stale/fresh the truck's position is, not just trust that
  /// a refresh is silently happening somewhere.
  testWidgets(
    'shows a visible countdown to the next refresh alongside the live badge',
    (tester) async {
      final job = _job(
        lastKnownLocation: GpsLocation(
          lat: -6.75,
          lng: 39.25,
          heading: 90,
          recordedAt: DateTime.now(),
          speedKmh: 40,
        ),
        gpsTrackingActive: true,
        gpsSignalStatus: 'ok',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LiveGpsTrackingScreen(
            job: job,
            onRefresh: () async => job,
            routingService: _FakeRoutingService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('next in 12s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('next in 11s'), findsOneWidget);

      // Ticks down to the refresh, then resets to a fresh 12s countdown.
      await tester.pump(const Duration(seconds: 11));
      expect(find.textContaining('next in 12s'), findsOneWidget);
    },
  );

  /// The whole point of this feature — the truck's own live position uses
  /// the same glyph as FleetMapScreen (TruckFleetMarker), not the old
  /// plain pulsing dot, so a transporter sees one consistent truck icon
  /// everywhere in the app.
  testWidgets(
    'shows the shared truck fleet marker, green and labelled, while live',
    (tester) async {
      final job = _job(
        status: 'in_transit',
        lastKnownLocation: GpsLocation(
          lat: -6.8,
          lng: 39.22,
          heading: 90,
          recordedAt: DateTime.now(),
          speedKmh: 40,
        ),
        gpsTrackingActive: true,
        gpsSignalStatus: 'ok',
        assignedTruckRegistration: 'T 123 ABC',
        assignedDriverName: 'Juma',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LiveGpsTrackingScreen(
            job: job,
            onRefresh: () async => job,
            routingService: _FakeRoutingService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TruckFleetMarker), findsOneWidget);
      final marker = tester.widget<TruckFleetMarker>(
        find.byType(TruckFleetMarker),
      );
      expect(marker.color, AppColors.statusLive);
      expect(marker.label, 'T 123 ABC Juma');
    },
  );

  testWidgets(
    'shows the truck fleet marker in red once the GPS signal is lost',
    (tester) async {
      final job = _job(
        status: 'in_transit',
        lastKnownLocation: GpsLocation(
          lat: -6.8,
          lng: 39.22,
          heading: 90,
          recordedAt: DateTime.now(),
          speedKmh: 0,
        ),
        gpsTrackingActive: true,
        gpsSignalStatus: 'lost',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LiveGpsTrackingScreen(
            job: job,
            onRefresh: () async => job,
            routingService: _FakeRoutingService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final marker = tester.widget<TruckFleetMarker>(
        find.byType(TruckFleetMarker),
      );
      expect(marker.color, AppColors.statusError);
    },
  );
}
