import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../config/app_config.dart';

class PlaceResult {
  const PlaceResult({required this.point, required this.displayName});

  final LatLng point;
  final String displayName;
}

/// Mapbox's Geocoding API once `AppConfig.mapboxAccessToken` is
/// configured, falling back to Nominatim (OpenStreetMap's own free
/// geocoder, no key needed) otherwise — see AppMap's docblock for why
/// Mapbox is the preferred choice and why the fallback exists at all.
/// Nominatim's usage policy caps public requests at ~1/second and requires
/// a real User-Agent identifying the app (an anonymous/browser-default one
/// gets silently blocked, not just rate-limited); search is only ever
/// triggered by an explicit user action (submitting the search field),
/// never on every keystroke, so this app can't realistically exceed that
/// on its own even while running on the fallback path.
///
/// Best-effort like every other external integration in this app (SMS,
/// push, Selcom): a failed or empty lookup returns an empty list/null
/// rather than throwing, since "no results" and "the network hiccuped"
/// look the same to a user typing a place name.
class GeocodingService {
  GeocodingService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              headers: {
                'User-Agent':
                    'CargoMotives/1.0 (contact: hussamullow@gmail.com)',
              },
            ),
          );

  final Dio _dio;

  /// [near] biases ranking toward whatever the map is currently centered
  /// on (proximity, not a hard filter) — without it, an ambiguous local
  /// name that exists in several regions (a common pattern for
  /// neighborhood/street names) tends to surface the wrong one first.
  /// No `types` filter is passed to Mapbox deliberately: leaving it unset
  /// searches every index it has (address, street, neighborhood, place/
  /// town, and POI/landmark) instead of narrowing to just one of them, so
  /// a search for a street name, a town, or a well-known building/landmark
  /// all go through the same call.
  Future<List<PlaceResult>> search(String query, {LatLng? near}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final token = AppConfig.mapboxAccessToken;
    try {
      if (token.isNotEmpty) {
        final response = await _dio.get(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(trimmed)}.json',
          queryParameters: {
            'access_token': token,
            'limit': 8,
            // country=tz: this app only ever operates in Tanzania (see
            // phone_input.dart's Tanzania-only validation) — without it,
            // Mapbox's global index matches generic English place-name
            // fragments worldwide (e.g. "Mbezi Beach" returning "Beachwood
            // Canyon, Los Angeles") instead of the local place meant.
            'country': 'tz',
            if (near != null) 'proximity': '${near.longitude},${near.latitude}',
          },
        );

        final features = response.data['features'] as List;
        return features
            .map(
              (f) => PlaceResult(
                point: LatLng(
                  (f['center'] as List)[1] as double,
                  (f['center'] as List)[0] as double,
                ),
                displayName: f['place_name'] as String,
              ),
            )
            .toList();
      }

      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': trimmed,
          'format': 'jsonv2',
          'limit': 8,
          'addressdetails': 1,
          // Same reasoning as Mapbox's country=tz above — Nominatim has no
          // such restriction by default and can otherwise return a
          // same-named place well outside Tanzania.
          'countrycodes': 'tz',
        },
      );

      final results = response.data as List;
      return results
          .map(
            (r) => PlaceResult(
              point: LatLng(
                double.parse(r['lat'] as String),
                double.parse(r['lon'] as String),
              ),
              displayName: r['display_name'] as String,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// The address text under a dropped pin — best-effort, so a search-less
  /// tap-to-drop-a-pin still fills the address field for a user who never
  /// typed anything.
  Future<String?> reverse(LatLng point) async {
    final token = AppConfig.mapboxAccessToken;
    try {
      if (token.isNotEmpty) {
        final response = await _dio.get(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/${point.longitude},${point.latitude}.json',
          queryParameters: {'access_token': token, 'country': 'tz'},
        );

        final features = response.data['features'] as List;
        return features.isEmpty
            ? null
            : features.first['place_name'] as String?;
      }

      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': point.latitude,
          'lon': point.longitude,
          'format': 'jsonv2',
        },
      );

      return response.data['display_name'] as String?;
    } catch (_) {
      return null;
    }
  }
}
