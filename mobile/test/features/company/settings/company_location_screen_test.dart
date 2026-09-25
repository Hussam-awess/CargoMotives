import 'package:cargo_motives/core/map/app_map.dart';
import 'package:cargo_motives/core/map/geocoding_service.dart';
import 'package:cargo_motives/features/company/data/company_repository.dart';
import 'package:cargo_motives/features/company/settings/company_location_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../../../support/fake_company_repository.dart';

class _FakeGeocodingService extends GeocodingService {
  _FakeGeocodingService({this.searchResults = const []});

  final List<PlaceResult> searchResults;

  @override
  Future<List<PlaceResult>> search(String query, {LatLng? near}) async {
    return searchResults;
  }
}

void main() {
  testWidgets('tapping the map drops a pin', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyLocationScreen(
          initialLat: null,
          initialLng: null,
          repository: FakeCompanyRepository(),
          geocodingService: _FakeGeocodingService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppMapPin), findsNothing);

    await tester.tapAt(tester.getCenter(find.byType(AppMap)));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.byType(AppMapPin), findsOneWidget);
  });

  testWidgets('shows the existing pin when editing an already-set location', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyLocationScreen(
          initialLat: -6.8161,
          initialLng: 39.2803,
          repository: FakeCompanyRepository(),
          geocodingService: _FakeGeocodingService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppMapPin), findsOneWidget);
  });

  testWidgets('Save calls the repository with the dropped pin and pops with true', (tester) async {
    double? savedLat;
    double? savedLng;
    bool? lastResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => CompanyLocationScreen(
                    initialLat: null,
                    initialLng: null,
                    repository: FakeCompanyRepository(
                      onUpdateLocation: ({required lat, required lng}) async {
                        savedLat = lat;
                        savedLng = lng;
                        return const CompanyVerification(
                          status: 'approved',
                          rejectedReason: null,
                          companyName: 'Test Co',
                        );
                      },
                    ),
                    geocodingService: _FakeGeocodingService(),
                  ),
                ),
              );
              lastResult = result;
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tapAt(tester.getCenter(find.byType(AppMap)));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(savedLat, isNotNull);
    expect(savedLng, isNotNull);
    expect(lastResult, isTrue);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('Save without a pin shows an error and does not call the repository', (tester) async {
    var called = false;

    await tester.pumpWidget(
      MaterialApp(
        home: CompanyLocationScreen(
          initialLat: null,
          initialLng: null,
          repository: FakeCompanyRepository(
            onUpdateLocation: ({required lat, required lng}) async {
              called = true;
              return const CompanyVerification(status: 'approved', rejectedReason: null, companyName: 'Test Co');
            },
          ),
          geocodingService: _FakeGeocodingService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Drop a pin on the map first.'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('a failed save shows an error instead of popping', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyLocationScreen(
          initialLat: -6.8161,
          initialLng: 39.2803,
          repository: FakeCompanyRepository(
            onUpdateLocation: ({required lat, required lng}) async => throw Exception('network error'),
          ),
          geocodingService: _FakeGeocodingService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Could not save your location. Try again.'), findsOneWidget);
    expect(find.byType(CompanyLocationScreen), findsOneWidget);
  });

  testWidgets('selecting a search result drops the pin there', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyLocationScreen(
          initialLat: null,
          initialLng: null,
          repository: FakeCompanyRepository(),
          geocodingService: _FakeGeocodingService(
            searchResults: const [
              PlaceResult(point: LatLng(-6.8161, 39.2803), displayName: 'Kariakoo, Dar es Salaam'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Kariakoo');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Kariakoo, Dar es Salaam'), findsOneWidget);
    await tester.tap(find.text('Kariakoo, Dar es Salaam'));
    await tester.pumpAndSettle();

    expect(find.byType(AppMapPin), findsOneWidget);
  });
}
