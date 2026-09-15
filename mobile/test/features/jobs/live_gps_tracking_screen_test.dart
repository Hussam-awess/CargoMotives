import 'package:cargo_motives/core/map/app_map.dart';
import 'package:cargo_motives/features/jobs/data/job_repository.dart';
import 'package:cargo_motives/features/jobs/live_gps_tracking_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Job _job() => Job(
  id: 19,
  status: 'in_transit',
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
  assignedTruckRegistration: null,
  assignedDriverName: null,
  proofOfDelivery: null,
  bidsCount: 0,
);

void main() {
  testWidgets('the map, back button and status chip all render above the bottom info sheet', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LiveGpsTrackingScreen(job: _job())));
    await tester.pumpAndSettle();

    // Regression test for a bug where the bottom info sheet's Column (missing
    // `mainAxisSize: MainAxisSize.min`) defaulted to MainAxisSize.max and
    // expanded to cover the entire screen, hiding everything behind it.
    expect(find.byType(AppMap), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.text('GPS signal unavailable'), findsOneWidget);

    final sheetSize = tester.getSize(find.byKey(const Key('trackingInfoSheet')));
    final screenSize = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(sheetSize.height, lessThan(screenSize.height * 0.6));
  });

  testWidgets('shows speed and ETA once the truck is live and moving', (tester) async {
    final job = Job(
      id: 20,
      status: 'in_transit',
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
      assignedTruckRegistration: null,
      assignedDriverName: null,
      proofOfDelivery: null,
      bidsCount: 0,
      gpsTrackingActive: true,
      gpsSignalStatus: 'ok',
      lastKnownLocation: GpsLocation(lat: -6.75, lng: 39.25, heading: 90, recordedAt: DateTime.now(), speedKmh: 60),
    );

    await tester.pumpWidget(MaterialApp(home: LiveGpsTrackingScreen(job: job)));
    await tester.pumpAndSettle();

    expect(find.text('60 km/h'), findsOneWidget);
    expect(find.textContaining('ETA'), findsOneWidget);
  });

  testWidgets('hides ETA when the truck is reported stationary', (tester) async {
    final job = Job(
      id: 21,
      status: 'in_transit',
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
      assignedTruckRegistration: null,
      assignedDriverName: null,
      proofOfDelivery: null,
      bidsCount: 0,
      gpsTrackingActive: true,
      gpsSignalStatus: 'ok',
      lastKnownLocation: GpsLocation(lat: -6.75, lng: 39.25, heading: 90, recordedAt: DateTime.now(), speedKmh: 0),
    );

    await tester.pumpWidget(MaterialApp(home: LiveGpsTrackingScreen(job: job)));
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
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LiveGpsTrackingScreen(job: _job()))),
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
}
