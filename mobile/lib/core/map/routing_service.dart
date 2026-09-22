import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../config/app_config.dart';

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

/// Mapbox's Directions API once `AppConfig.mapboxAccessToken` is
/// configured, falling back to OSRM's public demo server otherwise — see
/// AppMap's docblock for why Mapbox is preferred and why the fallback
/// exists. OSRM's demo server is explicitly a demo/fair-use service per
/// its own project docs, not a production SLA — fine as a no-token
/// fallback, not something to lean on for real traffic.
///
/// Both share the same response shape (a GeoJSON route geometry plus
/// distance/duration), so this stays a single method rather than two
/// parallel code paths with duplicated parsing.
///
/// Best-effort: a failed route request degrades to no drawn route rather
/// than blocking job posting — the straight-line haversine distance
/// (job_geo.dart's kmBetween, already used throughout this app) is always
/// available as a fallback estimate.
class RoutingService {
  RoutingService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<RouteResult?> route(LatLng from, LatLng to) async {
    final token = AppConfig.mapboxAccessToken;
    try {
      final response = token.isNotEmpty
          ? await _dio.get(
              'https://api.mapbox.com/directions/v5/mapbox/driving/'
              '${from.longitude},${from.latitude};${to.longitude},${to.latitude}',
              queryParameters: {
                'overview': 'full',
                'geometries': 'geojson',
                'access_token': token,
              },
            )
          : await _dio.get(
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
