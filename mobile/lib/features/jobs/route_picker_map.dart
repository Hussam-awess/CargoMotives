import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../core/map/app_map.dart';
import '../../core/map/geocoding_service.dart';
import '../../core/map/routing_service.dart';
import '../../core/theme/app_theme.dart';

enum _PinMode { pickup, dropoff }

/// One combined map for both pickup and drop-off (replacing the earlier
/// two-separate-maps layout) — a search bar to find a place by name
/// (most customers don't know their own coordinates), a Pickup/Drop-off
/// toggle deciding which pin the next tap or search result moves, and —
/// once both pins are set — a real road-following route drawn between
/// them via RoutingService, with its distance/duration shown the way
/// Bolt/Uber-style apps do. Falls back gracefully at every external call:
/// a failed search shows "No results", a failed route just leaves no
/// line drawn (the straight-line haversine distance the caller already
/// computes from the coordinates is always available regardless).
class RoutePickerMap extends StatefulWidget {
  const RoutePickerMap({
    super.key,
    this.initialPickup,
    this.initialDropoff,
    required this.onPickupChanged,
    required this.onDropoffChanged,
    this.onRouteDistanceChanged,
    this.geocodingService,
    this.routingService,
  });

  final LatLng? initialPickup;
  final LatLng? initialDropoff;
  final void Function(LatLng point, String? address) onPickupChanged;
  final void Function(LatLng point, String? address) onDropoffChanged;

  /// The real road-following distance once both pins are set and routing
  /// succeeds; null before that or if it fails — lets the caller prefer
  /// this over its own straight-line estimate without showing two
  /// different numbers for the same trip.
  final void Function(double? km)? onRouteDistanceChanged;
  final GeocodingService? geocodingService;
  final RoutingService? routingService;

  @override
  State<RoutePickerMap> createState() => _RoutePickerMapState();
}

class _RoutePickerMapState extends State<RoutePickerMap> {
  late final _geocoding = widget.geocodingService ?? GeocodingService();
  late final _routing = widget.routingService ?? RoutingService();
  final _mapController = MapController();
  final _searchController = TextEditingController();

  late LatLng? _pickup = widget.initialPickup;
  late LatLng? _dropoff = widget.initialDropoff;
  _PinMode _mode = _PinMode.pickup;

  List<PlaceResult> _searchResults = [];
  bool _searching = false;
  bool _searchFailed = false;

  RouteResult? _route;
  bool _isFetchingRoute = false;

  @override
  void initState() {
    super.initState();
    if (_pickup != null && _dropoff != null) _fetchRoute();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setRoute(RouteResult? route) {
    _route = route;
    widget.onRouteDistanceChanged?.call(route?.distanceKm);
  }

  Future<void> _fetchRoute() async {
    final pickup = _pickup;
    final dropoff = _dropoff;
    if (pickup == null || dropoff == null) return;

    setState(() => _isFetchingRoute = true);
    final result = await _routing.route(pickup, dropoff);
    if (!mounted) return;
    setState(() {
      _setRoute(result);
      _isFetchingRoute = false;
    });
  }

  Future<void> _setPin(LatLng point) async {
    setState(() {
      if (_mode == _PinMode.pickup) {
        _pickup = point;
      } else {
        _dropoff = point;
      }
      _setRoute(null);
    });

    // Best-effort address fill — a tap-to-drop-a-pin shouldn't require
    // also typing the address by hand.
    final address = await _geocoding.reverse(point);
    if (!mounted) return;

    if (_mode == _PinMode.pickup) {
      widget.onPickupChanged(point, address);
      // Auto-advance to drop-off the first time only — once both pins
      // exist, the toggle is the only way to switch modes, so re-tapping
      // to adjust pickup doesn't unexpectedly jump to drop-off.
      if (_dropoff == null) setState(() => _mode = _PinMode.dropoff);
    } else {
      widget.onDropoffChanged(point, address);
    }

    if (_pickup != null && _dropoff != null) _fetchRoute();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _searching = true;
      _searchFailed = false;
    });

    final results = await _geocoding.search(query);
    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _searching = false;
      _searchFailed = results.isEmpty;
    });
  }

  void _selectResult(PlaceResult result) {
    _mapController.move(result.point, 15);
    setState(() {
      _searchResults = [];
      _searchController.clear();
    });
    FocusScope.of(context).unfocus();

    setState(() {
      if (_mode == _PinMode.pickup) {
        _pickup = result.point;
      } else {
        _dropoff = result.point;
      }
      _setRoute(null);
    });
    if (_mode == _PinMode.pickup) {
      widget.onPickupChanged(result.point, result.displayName);
      if (_dropoff == null) setState(() => _mode = _PinMode.dropoff);
    } else {
      widget.onDropoffChanged(result.point, result.displayName);
    }
    if (_pickup != null && _dropoff != null) _fetchRoute();
  }

  @override
  Widget build(BuildContext context) {
    final fit = AppMap.fit([
      if (_pickup != null) _pickup!,
      if (_dropoff != null) _dropoff!,
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search for a place',
            // A tappable button, not just a decorative icon — relying on
            // the keyboard's "done"/"search" action alone (onSubmitted)
            // is flaky on Flutter Web's canvas renderer, where Enter
            // doesn't always reach the TextField's input handler.
            prefixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => _search(_searchController.text),
            ),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            isDense: true,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: _search,
        ),
        if (_searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: AppColors.border),
              itemBuilder: (context, index) {
                final result = _searchResults[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.place_outlined),
                  title: Text(
                    result.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _selectResult(result),
                );
              },
            ),
          ),
        if (_searchFailed)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'No results found.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ),
        const SizedBox(height: 10),
        SegmentedButton<_PinMode>(
          segments: [
            ButtonSegment(
              value: _PinMode.pickup,
              label: const Text('Pickup'),
              icon: Icon(Icons.circle, size: 12, color: AppColors.statusLive),
            ),
            ButtonSegment(
              value: _PinMode.dropoff,
              label: const Text('Drop-off'),
              icon: Icon(Icons.circle, size: 12, color: AppColors.statusError),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (selection) =>
              setState(() => _mode = selection.first),
        ),
        const SizedBox(height: 8),
        Text(
          _mode == _PinMode.pickup
              ? 'Tap the map (or search above) to set the pickup point.'
              : 'Tap the map (or search above) to set the drop-off point.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 260,
            child: Stack(
              children: [
                AppMap(
                  controller: _mapController,
                  initialCenter: fit.center,
                  initialZoom: fit.zoom,
                  onTap: (point) => _setPin(point),
                  polylines: [
                    if (_route != null)
                      Polyline(
                        points: _route!.points,
                        strokeWidth: 4,
                        color: AppColors.ctaBlue,
                      ),
                  ],
                  markers: [
                    if (_pickup != null)
                      Marker(
                        point: _pickup!,
                        width: 36,
                        height: 36,
                        alignment: Alignment.topCenter,
                        child: AppMapPin(color: AppColors.statusLive),
                      ),
                    if (_dropoff != null)
                      Marker(
                        point: _dropoff!,
                        width: 36,
                        height: 36,
                        alignment: Alignment.topCenter,
                        child: AppMapPin(color: AppColors.statusError),
                      ),
                  ],
                ),
                if (_isFetchingRoute)
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                if (_route != null)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(color: Color(0x33000000), blurRadius: 4),
                        ],
                      ),
                      child: Text(
                        '${_route!.distanceKm.toStringAsFixed(1)} km · ${_route!.durationMinutes.round()} min',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
