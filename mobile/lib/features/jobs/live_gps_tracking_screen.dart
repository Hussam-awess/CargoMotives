import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'data/job_repository.dart';
import 'job_geo.dart';
import 'job_status.dart';
import 'map_placeholder.dart';
import 'messages_screen.dart';

/// "Live GPS tracking" (mockup) — a full-screen map view of a job's truck.
/// No `google_maps_flutter` widget yet (no API key provisioned — the same
/// documented, already-existing scope gap as the Job Detail GPS card since
/// Phase 6): a styled placeholder fills the exact space the real map will
/// occupy later, sized and positioned so swapping it in only ever touches
/// this one widget. Every number on the bottom sheet is real — distance
/// remaining (haversine from the truck's last known position to
/// drop-off), progress, driver/company — nothing here is a mockup
/// placeholder value.
class LiveGpsTrackingScreen extends StatelessWidget {
  const LiveGpsTrackingScreen({super.key, required this.job});

  final Job job;

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
    final isLive =
        job.gpsTrackingActive &&
        job.gpsSignalStatus == 'ok' &&
        location != null;

    return Scaffold(
      body: Stack(
        children: [
          const MapPlaceholder(child: PulsingMarker()),
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
                              ? _liveLabel(location.recordedAt)
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
                  onTap: () => _showMapComingSoon(context),
                ),
                const SizedBox(height: 8),
                MapFloatingButton(
                  icon: Icons.remove,
                  onTap: () => _showMapComingSoon(context),
                ),
                const SizedBox(height: 8),
                MapFloatingButton(
                  icon: Icons.my_location,
                  onTap: () => _showMapComingSoon(context),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              key: const Key('trackingInfoSheet'),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                  builder: (_) => MessagesScreen(jobId: job.id),
                                ),
                              ),
                              borderRadius: BorderRadius.circular(7),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
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
          ),
        ],
      ),
    );
  }

  void _showMapComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Interactive map controls arrive with the real map.'),
      ),
    );
  }

  String _liveLabel(DateTime recordedAt) {
    final diff = DateTime.now().difference(recordedAt.toLocal());
    if (diff.inMinutes < 1) return 'Live · updated just now';
    return 'Live · updated ${diff.inMinutes} min ago';
  }
}
