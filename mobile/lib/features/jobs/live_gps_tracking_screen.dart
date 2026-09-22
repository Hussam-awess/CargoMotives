import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../core/map/app_map.dart';
import '../../core/map/routing_service.dart';
import '../../core/theme/app_theme.dart';
import '../profiles/transporter_profile_screen.dart';
import 'data/job_repository.dart';
import 'job_geo.dart';
import 'job_status.dart';
import 'map_placeholder.dart';
import 'messages_screen.dart';

/// "Live GPS tracking" — a full-screen map view of a job's truck. A real
/// map (AppMap — OpenStreetMap, not Google Maps; see its own docblock for
/// why) showing pickup, drop-off, a real road-following route to whichever
/// of the two is next (RoutingService, the same one JobRouteMapScreen
/// already uses for its own pre-bid preview), and the truck's live
/// position. Every number on the bottom sheet is real — distance
/// remaining (haversine from the truck's last known position to
/// drop-off), progress, speed (as reported by the truck's own connected
/// GPS provider), an ETA derived from that real speed and distance
/// (hidden rather than shown as a wild guess whenever the truck is
/// stationary), driver/company — nothing here is a mockup placeholder
/// value.
class LiveGpsTrackingScreen extends StatefulWidget {
  LiveGpsTrackingScreen({
    super.key,
    required this.job,
    required this.onRefresh,
    RoutingService? routingService,
  }) : routingService = routingService ?? RoutingService();

  final Job job;

  /// Re-fetches this job from whichever endpoint the caller's own role
  /// actually has access to — a customer's job and a company's assigned
  /// job are two different backend routes (JobController::show() vs
  /// CompanyJobController::show()), so this screen (shared by both roles)
  /// can't hardcode one repository itself. Each caller supplies its own
  /// one-liner, e.g. `() => jobRepository.show(job.id)`.
  final Future<Job> Function() onRefresh;

  final RoutingService routingService;

  @override
  State<LiveGpsTrackingScreen> createState() => _LiveGpsTrackingScreenState();
}

class _LiveGpsTrackingScreenState extends State<LiveGpsTrackingScreen> {
  // The backend's own GPS poller fetches fresh provider positions at most
  // once a minute (PollGpsPositionsJob) — polling faster than that just
  // re-requests the same data, but this still means a position or status
  // change reaches the screen within seconds rather than only whenever the
  // screen happens to be reopened. Route recomputation rides the same
  // tick rather than firing on every individual position change, so a
  // routing API call happens at most this often too.
  //
  // Ticked via a 1-second Timer.periodic (see _tick), not a single
  // Timer.periodic(_refreshCountdownSeconds) calling _refresh() directly
  // — the visible countdown badge needs a value to count down every
  // second, and driving both the badge and the actual refresh off the
  // same tick keeps them from ever drifting apart.
  static const _refreshCountdownSeconds = 12;

  final _mapController = MapController();
  Timer? _refreshTimer;
  late Job _job;
  RouteResult? _route;
  int _secondsUntilRefresh = _refreshCountdownSeconds;

  Job get job => _job;

  @override
  void initState() {
    super.initState();
    _job = widget.job;
    _loadRoute();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _tick() {
    setState(() => _secondsUntilRefresh -= 1);
    if (_secondsUntilRefresh <= 0) {
      setState(() => _secondsUntilRefresh = _refreshCountdownSeconds);
      _refresh();
    }
  }

  /// Deliberately silent (no loading spinner, no error state) — a failed
  /// background refresh just keeps showing the last-known position and
  /// tries again on the next tick, same as the map itself doing nothing
  /// while briefly offline.
  Future<void> _refresh() async {
    try {
      final fresh = await widget.onRefresh();
      if (!mounted) return;
      setState(() => _job = fresh);
      await _loadRoute();
    } catch (_) {
      // Swallowed — see docblock above.
    }
  }

  /// The current leg only — not the whole pickup-to-dropoff haul — since
  /// that's the one road route actually useful to look at right now: where
  /// the truck is headed next, from where it actually is. Never blocks on
  /// the routing call (RoutingService's own "best-effort" contract): a
  /// failed or unavailable request just means no polyline, the pickup/
  /// dropoff pins still render.
  Future<void> _loadRoute() async {
    final location = _job.lastKnownLocation;
    final pickup = _pickupPoint;
    final dropoff = _dropoffPoint;
    if (location == null || pickup == null || dropoff == null) {
      if (mounted) setState(() => _route = null);
      return;
    }

    final from = LatLng(location.lat, location.lng);
    final to = const ['assigned', 'en_route_pickup'].contains(_job.status)
        ? pickup
        : dropoff;

    final result = await widget.routingService.route(from, to);
    if (!mounted) return;
    setState(() => _route = result);
  }

  LatLng? get _pickupPoint => (_job.pickupLat != null && _job.pickupLng != null)
      ? LatLng(_job.pickupLat!, _job.pickupLng!)
      : null;

  LatLng? get _dropoffPoint =>
      (_job.dropoffLat != null && _job.dropoffLng != null)
      ? LatLng(_job.dropoffLat!, _job.dropoffLng!)
      : null;

  @override
  Widget build(BuildContext context) {
    final location = job.lastKnownLocation;
    final totalKm =
        (job.pickupLat != null &&
            job.pickupLng != null &&
            job.dropoffLat != null &&
            job.dropoffLng != null)
        ? kmBetween(
            job.pickupLat!,
            job.pickupLng!,
            job.dropoffLat!,
            job.dropoffLng!,
          )
        : null;
    final remainingKm =
        (location != null && job.dropoffLat != null && job.dropoffLng != null)
        ? kmBetween(
            location.lat,
            location.lng,
            job.dropoffLat!,
            job.dropoffLng!,
          )
        : null;
    final progress = (totalKm != null && remainingKm != null && totalKm > 0)
        ? (1 - (remainingKm / totalKm)).clamp(0.0, 1.0)
        : null;
    final speedKmh = location?.speedKmh;
    // Null rather than a fabricated number whenever the truck is reported
    // stationary/near-stationary — dividing by a near-zero speed would
    // otherwise show a wildly misleading "arrives in 400 hours".
    final etaMinutes = (remainingKm != null && speedKmh != null && speedKmh > 1)
        ? (remainingKm / speedKmh) * 60
        : null;
    final isLive =
        job.gpsTrackingActive &&
        job.gpsSignalStatus == 'ok' &&
        location != null;

    final pickupPoint = _pickupPoint;
    final dropoffPoint = _dropoffPoint;
    final truckPoint = location != null
        ? LatLng(location.lat, location.lng)
        : null;
    final fit = AppMap.fit([
      if (pickupPoint != null) pickupPoint,
      if (dropoffPoint != null) dropoffPoint,
      if (truckPoint != null) truckPoint,
    ]);

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
              if (pickupPoint != null)
                Marker(
                  point: pickupPoint,
                  width: 36,
                  height: 36,
                  alignment: Alignment.topCenter,
                  child: AppMapPin(color: AppColors.textSecondary),
                ),
              if (dropoffPoint != null)
                Marker(
                  point: dropoffPoint,
                  width: 36,
                  height: 36,
                  alignment: Alignment.topCenter,
                  child: const AppMapPin(),
                ),
              if (truckPoint != null)
                Marker(
                  point: truckPoint,
                  width: 110,
                  height: 56,
                  // Matches FleetMapScreen's own truck glyph exactly (see
                  // TruckFleetMarker's docblock) — the label anchors above
                  // the glyph, so topCenter keeps the glyph itself (not
                  // the label) sitting on the truck's actual position.
                  alignment: Alignment.topCenter,
                  child: TruckFleetMarker(
                    // Same green/red convention as the fleet map, just
                    // driven by this screen's own live-GPS signal (already
                    // shown in the status pill above) rather than a
                    // moving/stationary duration — this screen already
                    // has no other reasonable "moving" signal on hand.
                    color: isLive ? AppColors.statusLive : AppColors.statusError,
                    label: [
                      if (job.assignedTruckRegistration != null)
                        job.assignedTruckRegistration!,
                      if (job.assignedDriverName != null &&
                          job.assignedDriverName!.isNotEmpty)
                        job.assignedDriverName!,
                    ].join(' '),
                  ),
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
                  const SizedBox(width: 10),
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isLive
                                ? AppColors.ctaBlue
                                : AppColors.statusIdle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          isLive
                              ? '${_liveLabel(location.recordedAt)} · next in ${_secondsUntilRefresh}s'
                              : 'GPS signal unavailable',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 20,
            top: 108,
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
                  icon: Icons.my_location,
                  onTap: () {
                    if (truckPoint != null) {
                      _mapController.move(
                        truckPoint,
                        _mapController.camera.zoom,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          // A real DraggableScrollableSheet — a plain Align+Container here
          // only ever drew a handle bar that looked draggable but had no
          // drag behavior behind it, permanently blocking a fixed chunk of
          // the map underneath (the exact bug FleetMapScreen's own sheet
          // had). This one actually slides between a small peek (mostly
          // map, just the route/status header visible) and a tall sheet
          // showing every stat, with its own content scrollable if it
          // still overflows on a small screen.
          DraggableScrollableSheet(
            key: const Key('trackingInfoSheet'),
            initialChildSize: 0.4,
            minChildSize: 0.14,
            maxChildSize: 0.75,
            snap: true,
            snapSizes: const [0.14, 0.4, 0.75],
            builder: (context, scrollController) {
              return Container(
                key: const Key('trackingInfoSheetContent'),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  boxShadow: [
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
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 26),
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CM-${job.id.toString().padLeft(4, '0')}',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    '${job.pickupAddress} → ${job.dropoffAddress}',
                                    style: TextStyle(
                                      fontFamily: 'Barlow Condensed',
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.infoTint,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                jobStatusLabel(job.status),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ctaBluePressed,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (progress != null &&
                            totalKm != null &&
                            remainingKm != null) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 5,
                                    backgroundColor: AppColors.border,
                                    color: AppColors.ctaBlue,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${(totalKm - remainingKm).toStringAsFixed(0)} / ${totalKm.toStringAsFixed(0)} km',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textLabel,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (isLive &&
                            (speedKmh != null || etaMinutes != null)) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (speedKmh != null)
                                _StatChip(
                                  icon: Icons.speed,
                                  label: '${speedKmh.toStringAsFixed(0)} km/h',
                                ),
                              if (speedKmh != null && etaMinutes != null)
                                const SizedBox(width: 8),
                              if (etaMinutes != null)
                                _StatChip(
                                  icon: Icons.schedule,
                                  label: 'ETA ${_formatEta(etaMinutes)}',
                                ),
                            ],
                          ),
                        ],
                        if (job.assignedDriverName != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.local_shipping_outlined,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        job.assignedDriverName!,
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (job.assignedTruckRegistration != null)
                                        Text(
                                          job.assignedTruckRegistration!,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => MessagesScreen(
                                        jobId: job.id,
                                        counterpartyName:
                                            job.assignedCompanyName,
                                        onOpenCounterpartyProfile:
                                            job.assignedCompanyId != null
                                            ? () => Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      TransporterProfileScreen(
                                                        companyId: job
                                                            .assignedCompanyId!,
                                                      ),
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(7),
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: const Icon(
                                      Icons.chat_bubble_outline,
                                      size: 17,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

  String _liveLabel(DateTime recordedAt) {
    final diff = DateTime.now().difference(recordedAt.toLocal());
    if (diff.inMinutes < 1) return 'Live · updated just now';
    return 'Live · updated ${diff.inMinutes} min ago';
  }

  String _formatEta(double minutes) {
    if (minutes < 60) return '${minutes.round()} min';
    final hours = minutes / 60;
    return '${hours.toStringAsFixed(1)} hr';
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textLabel,
            ),
          ),
        ],
      ),
    );
  }
}
