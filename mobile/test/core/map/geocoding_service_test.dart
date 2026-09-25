import 'package:cargo_motives/core/map/geocoding_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// Intercepts every request and resolves it with a canned response instead
/// of hitting the network — captures the outgoing [RequestOptions] so a
/// test can assert on exactly what was sent (query params, path).
///
/// [AppConfig.mapboxAccessToken] is a compile-time `String.fromEnvironment`
/// value, and `flutter test` here runs with no `--dart-define`, so it's
/// always empty in this binary — meaning GeocodingService.search() always
/// takes the Nominatim branch under test, never the Mapbox one. That's
/// exactly the branch that had the real bug (no country restriction at
/// all), so it's the one worth covering.
class _CapturingAdapter extends InterceptorsWrapper {
  _CapturingAdapter({required this.responseData});

  final dynamic responseData;
  RequestOptions? lastRequest;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    lastRequest = options;
    handler.resolve(
      Response(requestOptions: options, data: responseData, statusCode: 200),
    );
  }
}

void main() {
  group('search (Nominatim fallback — no Mapbox token in this test binary)', () {
    late _CapturingAdapter interceptor;
    late GeocodingService service;

    void setUpWith(dynamic responseData) {
      interceptor = _CapturingAdapter(responseData: responseData);
      final dio = Dio()..interceptors.add(interceptor);
      service = GeocodingService(dio: dio);
    }

    test('restricts results to Tanzania and asks for up to 8 matches', () async {
      setUpWith([]);

      await service.search('Mwenge');

      final params = interceptor.lastRequest!.queryParameters;
      expect(interceptor.lastRequest!.path, contains('nominatim.openstreetmap.org'));
      expect(params['countrycodes'], 'tz');
      expect(params['limit'], 8);
      expect(params['q'], 'Mwenge');
    });

    test('parses street/town/POI results identically — Nominatim has no type filter', () async {
      setUpWith([
        {'lat': '-6.7924', 'lon': '39.2083', 'display_name': 'Mwenge, Kinondoni, Dar es Salaam, Tanzania'},
        {'lat': '-6.8161', 'lon': '39.2803', 'display_name': 'Uhuru Street, Dar es Salaam, Tanzania'},
      ]);

      final results = await service.search('Mwenge');

      expect(results, hasLength(2));
      expect(results[0].displayName, contains('Mwenge'));
      expect(results[0].point.latitude, closeTo(-6.7924, 0.0001));
      expect(results[1].displayName, contains('Uhuru Street'));
    });

    test('an empty query never reaches the network', () async {
      setUpWith([]);

      final results = await service.search('   ');

      expect(results, isEmpty);
      expect(interceptor.lastRequest, isNull);
    });

    test('a failed request returns an empty list rather than throwing', () async {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.reject(
              DioException(requestOptions: options, message: 'network down'),
            ),
          ),
        );
      final service = GeocodingService(dio: dio);

      final results = await service.search('Mwenge');

      expect(results, isEmpty);
    });
  });

  group('reverse (Nominatim fallback)', () {
    test('returns the display name under the dropped pin', () async {
      final interceptor = _CapturingAdapter(
        responseData: {'display_name': 'Kariakoo, Dar es Salaam, Tanzania'},
      );
      final dio = Dio()..interceptors.add(interceptor);
      final service = GeocodingService(dio: dio);

      final name = await service.reverse(const LatLng(-6.816, 39.28));

      expect(name, 'Kariakoo, Dar es Salaam, Tanzania');
      expect(interceptor.lastRequest!.queryParameters['lat'], -6.816);
      expect(interceptor.lastRequest!.queryParameters['lon'], 39.28);
    });
  });
}
