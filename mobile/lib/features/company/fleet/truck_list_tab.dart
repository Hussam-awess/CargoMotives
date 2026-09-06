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
  State<TruckListTab> createState() => _TruckListTabState();
}

class _TruckListTabState extends State<TruckListTab> {
  late Future<List<Truck>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.list();
  }

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
                children: const [
                  SizedBox(height: 80),
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 48,
                    color: Color(0xFF9E9E9E),
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

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: trucks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final truck = trucks[index];

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

class _TruckCard extends StatelessWidget {
  const _TruckCard({required this.truck, this.onTap});

  final Truck truck;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: truck.photoUrls.isEmpty
                    ? Container(
                        width: 56,
                        height: 56,
                        color: const Color(0xFFF0F1F3),
                        child: const Icon(
                          Icons.local_shipping_outlined,
                          color: Color(0xFF9E9E9E),
                        ),
                      )
                    : Image.network(
                        truck.photoUrls.first,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 56,
                          height: 56,
                          color: const Color(0xFFF0F1F3),
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      truck.registrationNumber,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      truck.makeModel,
                      style: const TextStyle(color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 6),
                    _StatusDot(
                      color: switch (truck.verificationStatus) {
                        'approved' => AppColors.statusLive,
                        'rejected' => AppColors.statusError,
                        _ => AppColors.statusPending,
                      },
                      label: switch (truck.verificationStatus) {
                        'approved' => 'Verified',
                        'rejected' => 'Rejected — tap to fix',
                        _ => 'Pending verification',
                      },
                    ),
                    const SizedBox(height: 2),
                    _StatusDot(
                      color: truck.gpsStatus == 'connected'
                          ? AppColors.statusLive
                          : AppColors.statusIdle,
                      label: truck.gpsStatus == 'connected'
                          ? 'Live GPS Available'
                          : 'GPS Tracking Not Available',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
