import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import 'data/job_repository.dart';
import 'job_detail_screen.dart';

/// "Shipment posted" (mockup) — the confirmation shown right after a
/// customer posts a job, before transporters have started bidding. Real
/// data throughout (the just-created Job's id/route/status); no budget
/// figure is shown since a posted job has no price yet in this app —
/// bidding sets the price, not the customer at posting time.
class ShipmentPostedScreen extends StatelessWidget {
  const ShipmentPostedScreen({super.key, required this.job});

  final Job job;

  Future<void> _copyTrackingId(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(text: 'CM-${job.id.toString().padLeft(4, '0')}'),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tracking ID copied.')));
    }
  }

  Future<void> _shareShipment(BuildContext context) async {
    final text =
        'Cargo Motives shipment CM-${job.id.toString().padLeft(4, '0')}: ${job.pickupAddress} → ${job.dropoffAddress}';
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied — paste it anywhere to share.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            tooltip: 'Back to Home',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.infoTint,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFB5D9FD),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.local_shipping_outlined,
                      color: AppColors.ctaBlue,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Your shipment is live',
                    style: TextStyle(
                      fontFamily: 'Barlow Condensed',
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Transporters on the ${job.pickupAddress.split(',').first}–${job.dropoffAddress.split(',').first} lane\ncan see it now and start bidding.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(13),
                    color: AppColors.surfaceSubtle,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tracking ID',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              'CM-${job.id.toString().padLeft(4, '0')}',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        OutlinedButton(
                          onPressed: () => _copyTrackingId(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                          child: const Text(
                            'Copy',
                            style: TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _Row(
                    label: 'Route',
                    value: '${job.pickupAddress} → ${job.dropoffAddress}',
                  ),
                  _Row(
                    label: 'Cargo',
                    value: '${job.containerType} · ${job.containerSize}',
                    isLast: true,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 11,
                    ),
                    color: AppColors.infoTint,
                    child: Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.ctaBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Waiting for transporter offers',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ctaBluePressed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => JobDetailScreen(jobId: job.id),
                ),
              ),
              child: const Text('VIEW OFFERS'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _shareShipment(context),
              child: const Text('Share shipment'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.isLast = false});

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.background)),
            ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
