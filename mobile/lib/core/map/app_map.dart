import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../theme/app_theme.dart';

/// A real, interactive map — OpenStreetMap tiles via flutter_map, not
/// Google Maps. This project's Google Cloud billing has repeatedly failed
/// to accept a card (a real, ongoing regional-billing problem, not a
/// one-off), so `google_maps_flutter` sat in pubspec.yaml unused since
/// Phase 6 while every "map" screen showed [MapPlaceholder] instead. OSM's
/// public tile server needs no account, no key, and no billing at all —
/// the trade-off is plainer tile styling and no Google-specific data
/// (Street View, Places), neither of which this app ever needed for "show
/// a truck/pins on a map."
///
/// `userAgentPackageName` is required by OSM's tile usage policy (a
/// missing/generic User-Agent gets a client blocked, not just warned), and
/// the attribution text is a hard requirement of using the free tile
/// server at all — both are non-negotiable, not decoration.
class AppMap extends StatelessWidget {
  const AppMap({
    super.key,
    required this.initialCenter,
    this.initialZoom = 13,
    this.controller,
    this.markers = const [],
    this.polylines = const [],
    this.onTap,
    this.interactive = true,
    this.minZoom = 3,
    this.maxZoom = 18,
  });

  final LatLng initialCenter;
  final double initialZoom;
  final MapController? controller;
  final List<Marker> markers;

  /// A route line (e.g. RoutingService's road-following geometry) drawn
  /// under the markers.
  final List<Polyline> polylines;
  final void Function(LatLng point)? onTap;
  final bool interactive;
  final double minZoom;
  final double maxZoom;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        minZoom: minZoom,
        maxZoom: maxZoom,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
        onTap: onTap == null ? null : (_, point) => onTap!(point),
        backgroundColor: AppColors.mapGround,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.cargomotives.cargo_motives',
          maxNativeZoom: 19,
        ),
        if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
        MarkerLayer(markers: markers),
        // Plain text, not RichAttributionWidget — that widget is
        // expandable/tappable (its own gesture + overlay), which left a
        // stray hit-testable region on screen even after navigating away
        // from the map in widget tests. OSM's attribution requirement only
        // needs the text visible, not an interactive control.
        const Positioned(
          left: 4,
          bottom: 2,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(color: Color(0x99FFFFFF)),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                child: Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 9, color: Colors.black87),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The smallest zoom level (whole-number steps, matching the map's own
  /// zoom granularity) that fits every point in [points] on screen at
  /// once, for an initial "show pickup, drop-off, and the truck" view
  /// without the caller hand-picking a zoom level that might not fit.
  static ({LatLng center, double zoom}) fit(List<LatLng> points) {
    if (points.isEmpty)
      return (center: const LatLng(-6.7924, 39.2083), zoom: 12);
    if (points.length == 1) return (center: points.first, zoom: 14);

    var minLat = points.first.latitude, maxLat = points.first.latitude;
    var minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points.skip(1)) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    final span = (maxLat - minLat).abs() > (maxLng - minLng).abs()
        ? (maxLat - minLat).abs()
        : (maxLng - minLng).abs();

    // A rough log2-style step-down: each doubling of the span drops the
    // zoom by one level, calibrated so two points a couple of kilometres
    // apart land around zoom 12-13 rather than zoomed in past useful.
    double zoom = 14;
    var remaining = span;
    while (remaining > 0.02 && zoom > 3) {
      remaining /= 2;
      zoom -= 1;
    }

    return (center: center, zoom: zoom);
  }
}

/// A pin-shaped marker, matching the mockup's map pins — distinct from
/// [PulsingMarker] (map_placeholder.dart), which stays in use for a live
/// truck position.
class AppMapPin extends StatelessWidget {
  const AppMapPin({
    super.key,
    this.color = AppColors.ctaBlue,
    this.icon = Icons.location_on,
  });

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      color: color,
      size: 36,
      shadows: const [
        Shadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2)),
      ],
    );
  }
}
