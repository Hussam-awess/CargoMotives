import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart' show LatLng;

class RouteResult {
  const RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
  });

  /// Road-following geometry, for drawing a Polyline — not a straight
  /// line between the two endpoints.
  final List<LatLng> points;
  final double distanceKm;
  final double durationMinutes;
}

/// OSRM's public demo server — free, no API key, matching this app's
/// no-billing constraint throughout (AppMap's tiles, GeocodingService's
/// search). Explicitly a demo/fair-use service per OSRM's own project
/// docs, not a production SLA: fine for this app's real-world traffic
/// today, but a genuine future scale-up should move to a paid host or a
/// self-hosted OSRM instance — same category of caveat already accepted
/// for the tile server, not a new one.
///
/// Best-effort: a failed route request degrades to no drawn route rather
/// than blocking job posting — the straight-line haversine distance
/// (job_geo.dart's kmBetween, already used throughout this app) is always
/// available as a fallback estimate.
class RoutingService {
  RoutingService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<RouteResult?> route(LatLng from, LatLng to) async {
    try {
      final response = await _dio.get(
        'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}',
        queryParameters: {'overview': 'full', 'geometries': 'geojson'},
      );

      final routes = response.data['routes'] as List;
      if (routes.isEmpty) return null;

      final route = routes.first as Map;
      final coordinates = (route['geometry']['coordinates'] as List)
          .map((c) => LatLng((c as List)[1] as double, c[0] as double))
          .toList();

      return RouteResult(
        points: coordinates,
        distanceKm: (route['distance'] as num) / 1000,
        durationMinutes: (route['duration'] as num) / 60,
      );
    } catch (_) {
      return null;
    }
  }
}
