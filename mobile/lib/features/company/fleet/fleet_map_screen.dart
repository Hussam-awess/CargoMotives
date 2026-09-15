import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../jobs/map_placeholder.dart';
import '../data/truck_repository.dart';

/// The Featured "fleet map" (AppFlow §2.7) — the company's own
/// GPS-connected trucks. No real map rendered yet (same documented scope
/// gap as Live GPS Tracking — no Google Maps API key provisioned): a
/// styled placeholder fills the map area, with a real bottom-sheet list
/// of the fleet's actual registration/status/last-known-position data
/// underneath, matching the mockup's map+sheet layout.
class FleetMapScreen extends StatefulWidget {
  FleetMapScreen({super.key, TruckRepository? repository})
    : repository = repository ?? TruckRepository();

  final TruckRepository repository;

  @override
  State<FleetMapScreen> createState() => _FleetMapScreenState();
}

class _FleetMapScreenState extends State<FleetMapScreen> {
  List<Truck> _trucks = [];
  bool _isLoading = true;
  bool _isForbidden = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
      _isForbidden = false;
    });

    try {
      final trucks = await widget.repository.map();
      if (mounted) setState(() => _trucks = trucks);
    } on ApiException catch (e) {
      if (mounted)
        setState(
          () => e.statusCode == 403
              ? _isForbidden = true
              : _loadError = 'Could not load your fleet map.',
        );
    } catch (_) {
      if (mounted)
        setState(() => _loadError = 'Could not load your fleet map.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isForbidden) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fleet map')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'The fleet map is a Featured-only feature. Upgrade to Featured to see your live fleet.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
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

    return Scaffold(
      body: Stack(
        children: [
          MapPlaceholder(child: _trucks.isEmpty ? null : const PulsingMarker()),
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
                      border: Border.all(color: const Color(0xFFC9A227)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.workspace_premium_outlined,
                          size: 14,
                          color: AppColors.lightBlue,
                        ),
                        SizedBox(width: 7),
                        Text(
                          'PLUS · FLEET MAP',
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
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 26),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
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
                              'Live',
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
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: _trucks.isEmpty
                          ? Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                'No GPS-connected trucks yet.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: _trucks.length,
                              separatorBuilder: (_, _) =>
                                  Divider(height: 1, color: AppColors.border),
                              itemBuilder: (context, index) =>
                                  _TruckPositionRow(truck: _trucks[index]),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
                Text(
                  hasPosition
                      ? '${truck.lastKnownLat!.toStringAsFixed(3)}, ${truck.lastKnownLng!.toStringAsFixed(3)} · ${_relativeTime(truck.lastKnownAt!)}'
                      : 'Waiting for the first position…',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
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
