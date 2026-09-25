import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../core/map/app_map.dart';
import '../../core/map/routing_service.dart';
import '../../core/theme/app_theme.dart';
import 'data/job_repository.dart';
import 'job_geo.dart';
import 'map_placeholder.dart';

/// A read-only preview of a job's pickup → drop-off route — for a company
/// still deciding whether to bid (no truck assigned yet, so
/// LiveGpsTrackingScreen's live-position map doesn't apply). Shows both
/// pins, a real road-following route when RoutingService succeeds, and
/// falls back to the straight-line haversine distance (job_geo.dart's
/// kmBetween, already used everywhere else in this app) when it doesn't —
/// never blocks on the routing call.
class JobRouteMapScreen extends StatefulWidget {
  const JobRouteMapScreen({super.key, required this.job, this.routingService});

  final Job job;
  final RoutingService? routingService;

  @override
  State<JobRouteMapScreen> createState() => _JobRouteMapScreenState();
}

class _JobRouteMapScreenState extends State<JobRouteMapScreen> {
  late final _routing = widget.routingService ?? RoutingService();
  final _mapController = MapController();
  final _sheetController = DraggableScrollableController();

  RouteResult? _route;
  bool _isLoadingRoute = true;

  /// Collapses the route sheet down to its minimum peek so the map fills
  /// almost the whole screen — an explicit "extended map" option, same as
  /// LiveGpsTrackingScreen's own fullscreen toggle, so a transporter isn't
  /// left with only a small, sheet-obscured strip of a freshly assigned
  /// shipment's route.
  bool _isMapExpanded = false;

  Job get job => widget.job;

  LatLng? get _pickupPoint => (job.pickupLat != null && job.pickupLng != null)
      ? LatLng(job.pickupLat!, job.pickupLng!)
      : null;

  LatLng? get _dropoffPoint =>
      (job.dropoffLat != null && job.dropoffLng != null)
      ? LatLng(job.dropoffLat!, job.dropoffLng!)
      : null;

  @override
  void initState() {
    super.initState();
    _loadRoute();
    _sheetController.addListener(_syncExpandedFromSheet);
  }

  @override
  void dispose() {
    _sheetController.removeListener(_syncExpandedFromSheet);
    _sheetController.dispose();
    super.dispose();
  }

  /// Keeps the fullscreen button's icon truthful even when the user
  /// dragged the sheet by hand instead of tapping it.
  void _syncExpandedFromSheet() {
    if (!_sheetController.isAttached) return;
    final expanded = _sheetController.size <= 0.2;
    if (expanded != _isMapExpanded) setState(() => _isMapExpanded = expanded);
  }

  void _toggleMapExpanded() {
    final expanding = !_isMapExpanded;
    _sheetController.animateTo(
      expanding ? 0.12 : 0.32,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
    setState(() => _isMapExpanded = expanding);
  }

  Future<void> _loadRoute() async {
    final pickup = _pickupPoint;
    final dropoff = _dropoffPoint;
    if (pickup == null || dropoff == null) {
      setState(() => _isLoadingRoute = false);
      return;
    }

    final result = await _routing.route(pickup, dropoff);
    if (!mounted) return;
    setState(() {
      _route = result;
      _isLoadingRoute = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pickup = _pickupPoint;
    final dropoff = _dropoffPoint;

    if (pickup == null || dropoff == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Route')),
        body: const MapPlaceholder(
          child: Text('Route not available for this job.'),
        ),
      );
    }

    // Prefer the real road-following distance once it's in; the plain
    // haversine estimate is shown immediately and while routing is
    // still loading, so the screen is never blank on that number.
    final straightLineKm = kmBetween(
      pickup.latitude,
      pickup.longitude,
      dropoff.latitude,
      dropoff.longitude,
    );
    final distanceKm = _route?.distanceKm ?? straightLineKm;
    final fit = AppMap.fit([pickup, dropoff]);

    return Scaffold(
      body: Stack(
        children: [
          AppMap(
            controller: _mapController,
            initialCenter: fit.center,
            initialZoom: fit.zoom,
            polylines: [
              if (_route != null)
                Polyline(
                  points: _route!.points,
                  strokeWidth: 4,
                  color: AppColors.ctaBlue,
                ),
            ],
            markers: [
              Marker(
                point: pickup,
                width: 36,
                height: 36,
                alignment: Alignment.topCenter,
                child: AppMapPin(color: AppColors.statusLive),
              ),
              Marker(
                point: dropoff,
                width: 36,
                height: 36,
                alignment: Alignment.topCenter,
                child: const AppMapPin(),
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  MapFloatingButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 20,
            top: 68,
            child: Column(
              children: [
                MapFloatingButton(
                  icon: Icons.add,
                  onTap: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom + 1,
                  ),
                ),
                const SizedBox(height: 8),
                MapFloatingButton(
                  icon: Icons.remove,
                  onTap: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom - 1,
                  ),
                ),
                const SizedBox(height: 8),
                MapFloatingButton(
                  icon: _isMapExpanded
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen,
                  onTap: _toggleMapExpanded,
                ),
              ],
            ),
          ),
          // A real DraggableScrollableSheet — a plain Align+Container here
          // only ever drew a static bar that permanently blocked a fixed
          // chunk of the map underneath (the exact bug LiveGpsTrackingScreen
          // and FleetMapScreen's own sheets already had). This one actually
          // slides between a small peek (mostly map, just the route header
          // visible) and a taller sheet showing the distance/time stats,
          // with its own content scrollable if it still overflows.
          DraggableScrollableSheet(
            key: const Key('routeMapSheet'),
            controller: _sheetController,
            initialChildSize: 0.32,
            minChildSize: 0.12,
            maxChildSize: 0.6,
            snap: true,
            snapSizes: const [0.12, 0.32, 0.6],
            builder: (context, scrollController) {
              return Container(
                key: const Key('routeMapSheetContent'),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F1D2D3D),
                      blurRadius: 20,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.statusLive,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                job.pickupAddress,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Container(
                            width: 1.5,
                            height: 16,
                            color: AppColors.border,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 12,
                              color: AppColors.statusError,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                job.dropoffAddress,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.only(top: 13),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: AppColors.background),
                            ),
                          ),
                          child: Row(
                            children: [
                              _RouteStat(
                                label: 'Distance',
                                value: _isLoadingRoute
                                    ? '…'
                                    : '${distanceKm.toStringAsFixed(0)} km',
                              ),
                              if (_route != null) ...[
                                const SizedBox(width: 24),
                                _RouteStat(
                                  label: 'Est. driving time',
                                  value: _formatDuration(
                                    _route!.durationMinutes,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(double minutes) {
    if (minutes < 60) return '${minutes.round()} min';
    final hours = minutes / 60;
    return '${hours.toStringAsFixed(1)} hr';
  }
}

class _RouteStat extends StatelessWidget {
  const _RouteStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Barlow Condensed',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
