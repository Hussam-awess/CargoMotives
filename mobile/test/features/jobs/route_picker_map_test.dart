import 'package:cargo_motives/core/map/app_map.dart';
import 'package:cargo_motives/core/map/geocoding_service.dart';
import 'package:cargo_motives/core/map/routing_service.dart';
import 'package:cargo_motives/features/customer/addresses/saved_addresses_screen.dart'
    show SavedAddress;
import 'package:cargo_motives/features/jobs/route_picker_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

class _FakeGeocodingService extends GeocodingService {
  _FakeGeocodingService({this.searchResults = const [], this.reverseResult});

  final List<PlaceResult> searchResults;
  final String? reverseResult;
  String? lastSearchQuery;

  @override
  Future<List<PlaceResult>> search(String query) async {
    lastSearchQuery = query;
    return searchResults;
  }

  @override
  Future<String?> reverse(LatLng point) async => reverseResult;
}

class _FakeRoutingService extends RoutingService {
  _FakeRoutingService({this.result});

  final RouteResult? result;

  @override
  Future<RouteResult?> route(LatLng from, LatLng to) async => result;
}

Widget _appUnder(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets(
    'tapping the map sets a green pickup pin and advances to drop-off mode',
    (tester) async {
      LatLng? pickup;
      LatLng? dropoff;

      await tester.pumpWidget(
        _appUnder(
          RoutePickerMap(
            geocodingService: _FakeGeocodingService(),
            routingService: _FakeRoutingService(),
            onPickupChanged: (point, _) => pickup = point,
            onDropoffChanged: (point, _) => dropoff = point,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(tester.getCenter(find.byType(AppMap)));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(pickup, isNotNull);
      expect(dropoff, isNull);
      expect(find.byIcon(Icons.circle).at(0), findsOneWidget);

      // Second tap goes to drop-off — mode auto-advanced after the first pin.
      await tester.tapAt(tester.getCenter(find.byType(AppMap)));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(dropoff, isNotNull);
    },
  );

  testWidgets(
    'tapping the map reverse-geocodes an address for the dropped pin',
    (tester) async {
      String? address;

      await tester.pumpWidget(
        _appUnder(
          RoutePickerMap(
            geocodingService: _FakeGeocodingService(
              reverseResult: 'Kariakoo Market, Dar es Salaam',
            ),
            routingService: _FakeRoutingService(),
            onPickupChanged: (_, a) => address = a,
            onDropoffChanged: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(tester.getCenter(find.byType(AppMap)));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(address, 'Kariakoo Market, Dar es Salaam');
    },
  );

  testWidgets(
    'searching for a place lists results and selecting one sets the active pin',
    (tester) async {
      String? pickupAddress;

      await tester.pumpWidget(
        _appUnder(
          RoutePickerMap(
            geocodingService: _FakeGeocodingService(
              searchResults: const [
                PlaceResult(
                  point: LatLng(-6.8, 39.28),
                  displayName: 'Kariakoo Market, Dar es Salaam',
                ),
              ],
            ),
            routingService: _FakeRoutingService(),
            onPickupChanged: (_, address) => pickupAddress = address,
            onDropoffChanged: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Kariakoo');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Kariakoo Market, Dar es Salaam'), findsOneWidget);

      await tester.tap(find.text('Kariakoo Market, Dar es Salaam'));
      await tester.pumpAndSettle();

      expect(pickupAddress, 'Kariakoo Market, Dar es Salaam');
      expect(find.text('Kariakoo Market, Dar es Salaam'), findsNothing);
    },
  );

  testWidgets(
    'a route is fetched and its distance/duration shown once both pins are set',
    (tester) async {
      await tester.pumpWidget(
        _appUnder(
          RoutePickerMap(
            initialPickup: const LatLng(-6.8, 39.28),
            initialDropoff: const LatLng(-6.9, 39.3),
            geocodingService: _FakeGeocodingService(),
            routingService: _FakeRoutingService(
              result: const RouteResult(
                points: [LatLng(-6.8, 39.28), LatLng(-6.9, 39.3)],
                distanceKm: 12.3,
                durationMinutes: 22,
              ),
            ),
            onPickupChanged: (_, _) {},
            onDropoffChanged: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('12.3 km · 22 min'), findsOneWidget);
    },
  );

  testWidgets(
    'a failed route lookup leaves the map usable with no distance shown',
    (tester) async {
      await tester.pumpWidget(
        _appUnder(
          RoutePickerMap(
            initialPickup: const LatLng(-6.8, 39.28),
            initialDropoff: const LatLng(-6.9, 39.3),
            geocodingService: _FakeGeocodingService(),
            routingService: _FakeRoutingService(result: null),
            onPickupChanged: (_, _) {},
            onDropoffChanged: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('km ·'), findsNothing);
      expect(find.byType(AppMap), findsOneWidget);
    },
  );

  testWidgets(
    'onModeChanged fires when the Pickup/Drop-off toggle changes',
    (tester) async {
      final modes = <MapPinMode>[];

      await tester.pumpWidget(
        _appUnder(
          RoutePickerMap(
            geocodingService: _FakeGeocodingService(),
            routingService: _FakeRoutingService(),
            onModeChanged: modes.add,
            onPickupChanged: (_, _) {},
            onDropoffChanged: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Drop-off'));
      await tester.pumpAndSettle();

      expect(modes, [MapPinMode.dropoff]);
    },
  );

  testWidgets(
    'no saved-address chips are shown when there are none to offer',
    (tester) async {
      await tester.pumpWidget(
        _appUnder(
          RoutePickerMap(
            geocodingService: _FakeGeocodingService(),
            routingService: _FakeRoutingService(),
            onPickupChanged: (_, _) {},
            onDropoffChanged: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ActionChip), findsNothing);
    },
  );

  testWidgets(
    'tapping a saved-address chip fills the active pin from its stored coordinates',
    (tester) async {
      LatLng? pickup;
      String? pickupAddress;

      await tester.pumpWidget(
        _appUnder(
          RoutePickerMap(
            geocodingService: _FakeGeocodingService(),
            routingService: _FakeRoutingService(),
            savedAddresses: const [
              SavedAddress(
                label: 'Warehouse',
                address: 'Kariakoo, Dar es Salaam',
                lat: -6.8161,
                lng: 39.2803,
              ),
            ],
            onPickupChanged: (point, address) {
              pickup = point;
              pickupAddress = address;
            },
            onDropoffChanged: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Warehouse'), findsOneWidget);
      await tester.tap(find.text('Warehouse'));
      await tester.pumpAndSettle();

      expect(pickup, const LatLng(-6.8161, 39.2803));
      expect(pickupAddress, 'Kariakoo, Dar es Salaam');
    },
  );

  testWidgets(
    'a saved address without stored coordinates falls back to geocoding its text',
    (tester) async {
      LatLng? pickup;
      String? pickupAddress;

      await tester.pumpWidget(
        _appUnder(
          RoutePickerMap(
            geocodingService: _FakeGeocodingService(
              searchResults: const [
                PlaceResult(
                  point: LatLng(-6.9, 39.3),
                  displayName: 'Mbezi Beach, Dar es Salaam',
                ),
              ],
            ),
            routingService: _FakeRoutingService(),
            savedAddresses: const [
              SavedAddress(
                label: 'Home',
                address: 'Mbezi Beach, Dar es Salaam',
              ),
            ],
            onPickupChanged: (point, address) {
              pickup = point;
              pickupAddress = address;
            },
            onDropoffChanged: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(pickup, const LatLng(-6.9, 39.3));
      expect(pickupAddress, 'Mbezi Beach, Dar es Salaam');
    },
  );

  testWidgets(
    'a saved address that fails to geocode shows an error and leaves pins unset',
    (tester) async {
      var pickupCalled = false;

      await tester.pumpWidget(
        _appUnder(
          RoutePickerMap(
            geocodingService: _FakeGeocodingService(),
            routingService: _FakeRoutingService(),
            savedAddresses: const [
              SavedAddress(label: 'Ghost', address: 'Nowhere at all'),
            ],
            onPickupChanged: (_, _) => pickupCalled = true,
            onDropoffChanged: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ghost'));
      await tester.pumpAndSettle();

      expect(pickupCalled, isFalse);
      expect(
        find.text('Could not locate "Ghost" on the map.'),
        findsOneWidget,
      );
    },
  );
}
