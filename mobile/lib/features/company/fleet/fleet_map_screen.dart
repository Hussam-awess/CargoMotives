import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../data/truck_repository.dart';

/// The Featured "fleet map" (AppFlow §2.7) — a simple map of the
/// company's own GPS-connected trucks. No real map rendered (same
/// documented scope decision as the Job Detail GPS card, Phase 6: no
/// Google Maps API key provisioned) — a live position readout per truck
/// instead, which still fully reflects the real data.
class FleetMapScreen extends StatefulWidget {
  FleetMapScreen({super.key, TruckRepository? repository}) : repository = repository ?? TruckRepository();

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
      if (mounted) setState(() => e.statusCode == 403 ? _isForbidden = true : _loadError = 'Could not load your fleet map.');
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Could not load your fleet map.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fleet map')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isForbidden
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('The fleet map is a Featured-only feature. Upgrade to Featured to see your live fleet.', textAlign: TextAlign.center),
              ),
            )
          : _loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [Text(_loadError!), const SizedBox(height: 12), OutlinedButton(onPressed: _load, child: const Text('Try again'))],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _trucks.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: const [SizedBox(height: 80), Center(child: Text('No GPS-connected trucks yet.'))],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _trucks.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _TruckPositionCard(truck: _trucks[index]),
                    ),
            ),
    );
  }
}

class _TruckPositionCard extends StatelessWidget {
  const _TruckPositionCard({required this.truck});

  final Truck truck;

  @override
  Widget build(BuildContext context) {
    final hasPosition = truck.lastKnownLat != null && truck.lastKnownAt != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.statusLive, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(truck.registrationNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            if (hasPosition) ...[
              Text('${truck.lastKnownLat!.toStringAsFixed(4)}, ${truck.lastKnownLng!.toStringAsFixed(4)}'),
              Text('Updated ${_relativeTime(truck.lastKnownAt!)}', style: Theme.of(context).textTheme.labelSmall),
            ] else
              const Text('Waiting for the first position…', style: TextStyle(color: AppColors.textSecondary)),
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
