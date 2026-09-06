import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'data/job_repository.dart';

/// The three GPS states a job screen can be in (TRD §5.3 — the same
/// "GPS is a badge, not a gate" principle as the bid card's GPS dot,
/// Phase 4): not connected at all, connected and live, or connected but
/// quiet. Deliberately a status readout, not a rendered map — no Google
/// Maps API key is provisioned yet (the same documented scope decision
/// PostJobScreen made for pickup/drop-off entry back in Phase 4); this
/// still fully exercises the live WebSocket data path, just not map tiles.
class GpsStatusCard extends StatelessWidget {
  const GpsStatusCard({super.key, required this.trackingActive, required this.signalStatus, required this.location});

  final bool trackingActive;
  final String signalStatus; // ok | lost | not_applicable
  final GpsLocation? location;

  @override
  Widget build(BuildContext context) {
    if (!trackingActive) {
      return _statusRow(
        context,
        color: AppColors.statusIdle,
        label: 'GPS Tracking Not Available',
        subtitle: 'This truck has no GPS connected.',
      );
    }

    if (signalStatus == 'lost') {
      return _statusRow(
        context,
        color: AppColors.statusPending,
        label: 'GPS signal unavailable',
        subtitle: location == null ? 'No position received yet.' : 'Last seen ${_relativeTime(location!.recordedAt)} at ${_coords(location!)}.',
      );
    }

    if (location == null) {
      return _statusRow(
        context,
        color: AppColors.statusLive,
        label: 'Live GPS Available',
        subtitle: 'Waiting for the first position…',
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.statusLive, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text('Live', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Text(_coords(location!)),
            if (location!.heading != null) Text('Heading: ${_compass(location!.heading!)}'),
            const SizedBox(height: 4),
            Text('Updated ${_relativeTime(location!.recordedAt)}', style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(BuildContext context, {required Color color, required String label, required String subtitle}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _coords(GpsLocation location) => '${location.lat.toStringAsFixed(4)}, ${location.lng.toStringAsFixed(4)}';

  String _compass(double heading) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((heading % 360) / 45).round() % 8;

    return '${directions[index]} (${heading.toStringAsFixed(0)}°)';
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';

    return '${diff.inHours}h ago';
  }
}
