import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/truck_repository.dart';
import 'add_truck_screen.dart';
import 'connect_gps_screen.dart' show GpsProviderOption;

/// Fleet Tab's truck list (UI/UX Brief §5.4): photo thumbnail, registration
/// number, availability, GPS status. Any truck is tappable to open its
/// details — trucks no longer go through an Admin review, so there's no
/// pending/rejected state to gate that on, though AddTruckScreen itself
/// locks most fields once a truck has real details on file (see its own
/// docblock). Deleting requires the truck to be both idle and
/// GPS-disconnected — a connected truck offers "Disconnect GPS" instead.
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
    // A block body, not an arrow (`() => _future = ...`) — an arrow
    // closure's value IS the assignment's value (a Future here), and
    // Flutter's setState() explicitly rejects a callback that returns one.
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _openAddTruck({Truck? edit}) async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            AddTruckScreen(repository: widget.repository, editTruck: edit),
      ),
    );
    if (added == true) await _refresh();
  }

  Future<void> _deleteTruck(Truck truck) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this truck?'),
        content: Text(
          '${truck.registrationNumber} will be removed from your fleet. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.repository.delete(truck.id);
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not remove that truck. Try again.'),
          ),
        );
      }
    }
  }

  /// The only way to unblock removing a GPS-connected truck (see
  /// TruckController::destroy()'s own guard) — a per-truck disconnect,
  /// distinct from FleetScreen's whole-connection Connect/Disconnect GPS
  /// toggle, which would affect every truck on that provider account.
  Future<void> _disconnectGps(Truck truck) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect from GPS?'),
        content: Text(
          '${truck.registrationNumber} will stop reporting its live position. '
          'You can reconnect it later, or remove the truck now that it\'s disconnected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.repository.disconnectGps(truck.id);
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not disconnect that truck. Try again.'),
          ),
        );
      }
    }
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
          final gpsConnectedCount = trucks
              .where((t) => t.gpsStatus == 'connected')
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
                    gpsConnected: gpsConnectedCount,
                  );
                }
                final truck = trucks[index - 1];

                return _TruckCard(
                  truck: truck,
                  onTap: () => _openAddTruck(edit: truck),
                  onDelete: (truck.isIdle && !truck.isGpsConnected)
                      ? () => _deleteTruck(truck)
                      : null,
                  onAddDetails: truck.isGpsImported
                      ? () => _openAddTruck(edit: truck)
                      : null,
                  onDisconnectGps: truck.isGpsConnected
                      ? () => _disconnectGps(truck)
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
    required this.gpsConnected,
  });

  final int total;
  final int onJob;
  final int gpsConnected;

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
            child: _Stat(value: gpsConnected, label: 'GPS on'),
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
  const _TruckCard({
    required this.truck,
    this.onTap,
    this.onDelete,
    this.onAddDetails,
    this.onDisconnectGps,
  });

  final Truck truck;
  final VoidCallback? onTap;

  /// Null when the truck is on a job, or still linked to a live GPS
  /// device — a company may only remove an idle, GPS-disconnected truck.
  final VoidCallback? onDelete;

  /// Set only for a GPS-imported truck (Truck.isGpsImported) — opens the
  /// same edit form tapping the card does, surfaced as its own button
  /// because a bare GPS import has no real make/model/capacity/photos/
  /// documents yet and the prompt to supply them needs to be obvious.
  final VoidCallback? onAddDetails;

  /// Set only while the truck is GPS-connected (Truck.isGpsConnected) —
  /// the only way to unblock deleting it, since a GPS-connected truck
  /// can't be removed directly.
  final VoidCallback? onDisconnectGps;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(13),
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
                            Flexible(
                              child: Text(
                                truck.makeModel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
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
                                color: AppColors.statusLive,
                                label: truck.currentStatus == 'on_job'
                                    ? 'On a job'
                                    : 'Available',
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
                        if (truck.isGpsImported)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Imported from ${GpsProviderOption.labelFor(truck.gpsProvider ?? '')}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontStyle: FontStyle.italic,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: onDelete != null
                          ? AppColors.statusError
                          : AppColors.textTertiary,
                    ),
                    tooltip: onDelete != null
                        ? 'Remove truck'
                        : !truck.isIdle
                        ? 'Only an idle truck (not on a job) can be removed'
                        : 'Disconnect this truck from GPS before removing it',
                    onPressed: onDelete,
                  ),
                ],
              ),
            ),
          ),
          if (onAddDetails != null || onDisconnectGps != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onAddDetails != null)
                    OutlinedButton.icon(
                      onPressed: onAddDetails,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Add details'),
                    ),
                  if (onDisconnectGps != null)
                    OutlinedButton.icon(
                      onPressed: onDisconnectGps,
                      icon: const Icon(Icons.link_off, size: 16),
                      label: const Text('Disconnect GPS'),
                    ),
                ],
              ),
            ),
        ],
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
