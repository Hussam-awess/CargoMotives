import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../core/map/app_map.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../jobs/map_placeholder.dart';
import '../data/truck_repository.dart';

/// The fleet map (AppFlow §2.7) — every transporter's own GPS-connected
/// trucks, not a Plus-only feature. A real map (AppMap — OpenStreetMap)
/// plots one marker per truck with a known position, with a real
/// bottom-sheet list of the fleet's actual registration/status/last-known-
/// position data underneath, matching the mockup's map+sheet layout.
class FleetMapScreen extends StatefulWidget {
  FleetMapScreen({super.key, TruckRepository? repository})
    : repository = repository ?? TruckRepository();

  final TruckRepository repository;

  @override
  State<FleetMapScreen> createState() => _FleetMapScreenState();
}

class _FleetMapScreenState extends State<FleetMapScreen> {
  // The GPS poller on the backend only fetches fresh provider positions
  // once a minute (PollGpsPositionsJob) — polling faster than that would
  // just re-request the same data, but polling this often still means any
  // position/status change reaches the screen within seconds of the next
  // provider poll, rather than only whenever the screen happens to reopen.
  //
  // Ticked via a 1-second Timer.periodic (see _tick) rather than a single
  // Timer.periodic(_refreshCountdownSeconds) that calls _refresh()
  // directly — the countdown badge in the sheet header needs a value to
  // count down every second, and driving both the badge and the actual
  // refresh off the same one-second tick keeps them from ever drifting
  // apart the way two independent timers could.
  static const _refreshCountdownSeconds = 12;

  List<Truck> _trucks = [];
  bool _isLoading = true;
  String? _loadError;
  Timer? _refreshTimer;
  int _secondsUntilRefresh = _refreshCountdownSeconds;

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final trucks = await widget.repository.map();
      if (mounted) setState(() => _trucks = trucks);
    } on ApiException catch (_) {
      if (mounted)
        setState(() => _loadError = 'Could not load your fleet map.');
    } catch (_) {
      if (mounted)
        setState(() => _loadError = 'Could not load your fleet map.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// The periodic live-refresh — deliberately silent (no loading spinner,
  /// no error state swap) so a real-time update never interrupts someone
  /// mid-scroll of the bottom sheet or mid-look at the map. A failed
  /// background refresh just keeps showing the last-known positions and
  /// tries again on the next tick, same as the map itself doing nothing
  /// while briefly offline.
  Future<void> _refresh() async {
    try {
      final trucks = await widget.repository.map();
      if (mounted) setState(() => _trucks = trucks);
    } catch (_) {
      // Swallowed — see docblock above.
    }
  }

  void _showTruckInfo(BuildContext context, Truck truck) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _TruckInfoSheet(truck: truck),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fleet map')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    final onJob = _trucks.where((t) => t.currentStatus == 'on_job').length;
    final available = _trucks
        .where(
          (t) =>
              t.currentStatus != 'on_job' && t.verificationStatus == 'approved',
        )
        .length;

    final points = _trucks
        .where((t) => t.lastKnownLat != null && t.lastKnownLng != null)
        .map((t) => LatLng(t.lastKnownLat!, t.lastKnownLng!))
        .toList();
    final fit = AppMap.fit(points);

    return Scaffold(
      body: Stack(
        children: [
          AppMap(
            initialCenter: fit.center,
            initialZoom: fit.zoom,
            markers: [
              for (final t in _trucks)
                if (t.lastKnownLat != null && t.lastKnownLng != null)
                  Marker(
                    point: LatLng(t.lastKnownLat!, t.lastKnownLng!),
                    width: 110,
                    height: 56,
                    // The label sits above the truck glyph, but the point
                    // itself must still resolve to the truck's actual
                    // position — topCenter anchors the marker's bottom
                    // edge (the glyph) at `point`, with the label
                    // floating above it, never the other way around.
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => _showTruckInfo(context, t),
                      child: TruckFleetMarker(
                        // Reflects live movement, not job status (a truck
                        // can be on a job while parked at a checkpoint, or
                        // idle while being repositioned) — the info sheet's
                        // own Status row still shows on-a-job/available
                        // separately. Green while actually moving, red once
                        // stationary for 15+ minutes or GPS-offline —
                        // matching Tracksolid Pro's own moving/stopped
                        // convention rather than this app's usual
                        // "grey = inactive" status color.
                        color: t.gpsMoving
                            ? AppColors.statusLive
                            : AppColors.statusError,
                        label: [
                          t.registrationNumber,
                          if (t.gpsDriverName != null &&
                              t.gpsDriverName!.isNotEmpty)
                            t.gpsDriverName!,
                        ].join(' '),
                      ),
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
                      color: AppColors.brandChip,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.map_outlined,
                          size: 14,
                          color: AppColors.lightBlue,
                        ),
                        SizedBox(width: 7),
                        Text(
                          'FLEET MAP',
                          style: TextStyle(
                            fontFamily: 'Barlow Condensed',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.lightBlue,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // A real DraggableScrollableSheet — the old version only drew a
          // handle bar that looked draggable but had no drag behavior
          // behind it at all, permanently blocking a fixed chunk of the
          // map. This one actually slides between a small peek (mostly
          // map, just the truck count visible) and a tall sheet (most of
          // the list, still scrollable within itself once fully expanded).
          DraggableScrollableSheet(
            key: const Key('fleetMapSheet'),
            initialChildSize: 0.32,
            minChildSize: 0.12,
            maxChildSize: 0.75,
            snap: true,
            snapSizes: const [0.12, 0.32, 0.75],
            builder: (context, scrollController) {
              return Container(
                key: const Key('fleetMapSheetContent'),
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
                  child: CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                          child: Column(
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'All ${_trucks.length} truck${_trucks.length == 1 ? '' : 's'}',
                                          style: TextStyle(
                                            fontFamily: 'Barlow Condensed',
                                            fontSize: 22,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        Text(
                                          '$onJob on a job · $available available',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: const BoxDecoration(
                                          color: AppColors.ctaBlue,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        // Visible, not just silently
                                        // happening in the background — a
                                        // moving truck's marker can jump a
                                        // noticeable distance between
                                        // refreshes, and a ticking count
                                        // tells a company exactly how
                                        // stale/fresh what they're looking
                                        // at is, right up to the moment it
                                        // updates.
                                        'Live · $_secondsUntilRefresh s',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textLabel,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_trucks.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 24,
                            ),
                            child: Text(
                              'No GPS-connected trucks yet.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverList.separated(
                            itemCount: _trucks.length,
                            separatorBuilder: (_, _) =>
                                Divider(height: 1, color: AppColors.border),
                            itemBuilder: (context, index) => InkWell(
                              onTap: () =>
                                  _showTruckInfo(context, _trucks[index]),
                              child: _TruckPositionRow(truck: _trucks[index]),
                            ),
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Live-activity label shared by the list row and the info sheet — one word
/// naming what the GPS is doing right now (not the job status), matching
/// Tracksolid Pro's own moving/stopped/offline vocabulary.
String _activityLabel(Truck truck) {
  if (!truck.gpsOnline) return 'Offline';
  return truck.gpsMoving ? 'Moving' : 'Stationary';
}

Color _activityColor(Truck truck) {
  if (!truck.gpsOnline) return AppColors.textSecondary;
  return truck.gpsMoving ? AppColors.statusLive : AppColors.statusError;
}

class _TruckPositionRow extends StatelessWidget {
  const _TruckPositionRow({required this.truck});

  final Truck truck;

  @override
  Widget build(BuildContext context) {
    final hasPosition = truck.lastKnownLat != null && truck.lastKnownAt != null;
    final isOnJob = truck.currentStatus == 'on_job';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnJob ? AppColors.ctaBlue : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      truck.makeModel,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      truck.registrationNumber,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasPosition
                            ? '${truck.lastKnownLat!.toStringAsFixed(3)}, ${truck.lastKnownLng!.toStringAsFixed(3)} · ${_relativeTime(truck.lastKnownAt!)}'
                            : 'Waiting for the first position…',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (hasPosition) ...[
                      const SizedBox(width: 6),
                      Text(
                        _activityLabel(truck),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _activityColor(truck),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';

    return '${diff.inHours}h ago';
  }
}

/// Shown on tapping a truck — either its map marker or its row in the
/// bottom sheet's list — with the two things AppFlow's spec calls out:
/// plate number and driver name. `driverName` only ever comes from a GPS
/// provider that reports one against the device itself (Tracksolid Pro
/// today, see Truck.gpsDriverName's own docblock), so it reads "Driver not
/// reported" rather than blank when a provider doesn't supply one.
class _TruckInfoSheet extends StatelessWidget {
  const _TruckInfoSheet({required this.truck});

  final Truck truck;

  @override
  Widget build(BuildContext context) {
    final hasPosition = truck.lastKnownLat != null && truck.lastKnownAt != null;
    final isOnJob = truck.currentStatus == 'on_job';

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
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
                    color: isOnJob ? AppColors.ctaBlue : AppColors.statusLive,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  truck.registrationNumber,
                  style: const TextStyle(
                    fontFamily: 'Barlow Condensed',
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              truck.makeModel,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            _InfoRow(
              icon: Icons.person_outline,
              label: 'Driver',
              value: truck.gpsDriverName ?? 'Driver not reported',
            ),
            _InfoRow(
              icon: isOnJob
                  ? Icons.local_shipping_outlined
                  : Icons.check_circle_outline,
              label: 'Status',
              value: isOnJob ? 'On a job' : 'Available',
            ),
            if (hasPosition)
              _InfoRow(
                icon: truck.gpsMoving
                    ? Icons.speed_outlined
                    : Icons.pause_circle_outline,
                label: 'Activity',
                value: _activityLabel(truck),
                valueColor: _activityColor(truck),
              ),
            _InfoRow(
              icon: Icons.place_outlined,
              label: 'Position',
              value: hasPosition
                  ? '${truck.lastKnownLat!.toStringAsFixed(4)}, ${truck.lastKnownLng!.toStringAsFixed(4)}'
                  : 'Waiting for the first position…',
            ),
            if (hasPosition)
              _InfoRow(
                icon: Icons.schedule,
                label: 'Last update',
                value: _relativeTime(truck.lastKnownAt!),
              ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';

    return '${diff.inHours}h ago';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
