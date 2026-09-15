import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart' show LatLng;

class PlaceResult {
  const PlaceResult({required this.point, required this.displayName});

  final LatLng point;
  final String displayName;
}

/// Nominatim (OpenStreetMap's own free geocoder) — no API key, same
/// no-billing constraint as AppMap's tile choice. Its usage policy caps
/// public requests at ~1/second and requires a real User-Agent identifying
/// the app (an anonymous/browser-default one gets silently blocked, not
/// just rate-limited) — search is only ever triggered by an explicit user
/// action (submitting the search field), never on every keystroke, so
/// this app can't realistically exceed that on its own.
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

  Future<List<PlaceResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {'q': trimmed, 'format': 'jsonv2', 'limit': 5},
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
    try {
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
