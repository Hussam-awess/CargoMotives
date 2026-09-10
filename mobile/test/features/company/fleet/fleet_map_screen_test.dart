import 'package:cargo_motives/core/network/api_exception.dart';
import 'package:cargo_motives/features/company/data/truck_repository.dart';
import 'package:cargo_motives/features/company/fleet/fleet_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_truck_repository.dart';

void main() {
  testWidgets('shows GPS-connected trucks with their last known position', (tester) async {
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

    expect(find.text('T 123 ABC'), findsOneWidget);
    expect(find.textContaining('-6.816, 39.280'), findsOneWidget);
  });

  testWidgets('shows an empty state when nothing is GPS-connected', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: FleetMapScreen(repository: FakeTruckRepository(onMap: () async => []))),
    );
    await tester.pumpAndSettle();

    expect(find.text('No GPS-connected trucks yet.'), findsOneWidget);
  });

  testWidgets('shows an upgrade prompt for a non-featured company (403)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FleetMapScreen(
          repository: FakeTruckRepository(onMap: () async => throw ApiException('Forbidden', statusCode: 403)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Featured-only feature'), findsOneWidget);
  });
}
