import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/truck_repository.dart';
import 'add_truck_screen.dart';

/// Fleet Tab's truck list (UI/UX Brief §5.4): photo thumbnail, registration
/// number, verification status, GPS status — a rejected truck is tappable
/// to fix and resubmit.
class TruckListTab extends StatefulWidget {
  TruckListTab({super.key, TruckRepository? repository})
    : repository = repository ?? TruckRepository();

  final TruckRepository repository;

  @override
  State<TruckListTab> createState() => TruckListTabState();
}

class TruckListTabState extends State<TruckListTab> {
  late Future<List<Truck>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.list();
  }

  /// Called by FleetScreen after Connect GPS imports vehicles, so newly
  /// GPS-connected trucks show up without the user needing to pull-to-refresh.
  Future<void> refresh() => _refresh();

  Future<void> _refresh() async {
    final future = widget.repository.list();
    setState(() => _future = future);
    await future;
  }

  Future<void> _openAddTruck({Truck? resubmit}) async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddTruckScreen(
          repository: widget.repository,
          resubmitTruck: resubmit,
        ),
      ),
    );
    if (added == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Truck>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load your trucks.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _refresh,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            );
          }

          final trucks = snapshot.data!;
          if (trucks.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  SizedBox(height: 80),
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 48,
                    color: AppColors.textTertiary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No trucks yet. Tap + to register your first one.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final onJobCount = trucks
              .where((t) => t.currentStatus == 'on_job')
              .length;
          final pendingCount = trucks
              .where((t) => t.verificationStatus == 'pending')
              .length;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: trucks.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _FleetStatsBar(
                    total: trucks.length,
                    onJob: onJobCount,
                    pendingVerification: pendingCount,
                  );
                }
                final truck = trucks[index - 1];

                return _TruckCard(
                  truck: truck,
                  onTap: truck.isRejected
                      ? () => _openAddTruck(resubmit: truck)
                      : null,
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddTruck(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _FleetStatsBar extends StatelessWidget {
  const _FleetStatsBar({
    required this.total,
    required this.onJob,
    required this.pendingVerification,
  });

  final int total;
  final int onJob;
  final int pendingVerification;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Stat(value: total, label: 'Trucks'),
          ),
          Container(width: 1, height: 40, color: AppColors.border),
          Expanded(
            child: _Stat(value: onJob, label: 'On a job'),
          ),
          Container(width: 1, height: 40, color: AppColors.border),
          Expanded(
            child: _Stat(value: pendingVerification, label: 'Pending'),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontFamily: 'Barlow Condensed',
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _TruckCard extends StatelessWidget {
  const _TruckCard({required this.truck, this.onTap});

  final Truck truck;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: truck.photoUrls.isEmpty
                  ? Container(
                      width: 48,
                      height: 48,
                      color: AppColors.border,
                      child: Icon(
                        Icons.local_shipping_outlined,
                        color: AppColors.textTertiary,
                      ),
                    )
                  : Image.network(
                      truck.photoUrls.first,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 48,
                        height: 48,
                        color: AppColors.border,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        truck.makeModel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        truck.registrationNumber,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${truck.vehicleType} · ${truck.capacityTons.toStringAsFixed(0)} t',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Chip(
                          color: switch (truck.verificationStatus) {
                            'approved' => AppColors.statusLive,
                            'rejected' => AppColors.statusError,
                            _ => AppColors.statusPending,
                          },
                          label: switch (truck.verificationStatus) {
                            'approved' =>
                              truck.currentStatus == 'on_job'
                                  ? 'On a job'
                                  : 'Available',
                            'rejected' => 'Rejected — tap to fix',
                            _ => 'Pending verification',
                          },
                        ),
                        _Chip(
                          color: truck.gpsStatus == 'connected'
                              ? AppColors.statusLive
                              : AppColors.statusIdle,
                          label: truck.gpsStatus == 'connected'
                              ? 'GPS on'
                              : 'GPS off',
                          filled: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.color, required this.label, this.filled = true});

  final Color color;
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.1) : AppColors.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: filled ? color : AppColors.textLabel,
            ),
          ),
        ],
      ),
    );
  }
}
