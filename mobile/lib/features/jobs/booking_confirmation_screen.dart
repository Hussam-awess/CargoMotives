import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import 'data/bid_repository.dart';
import 'data/job_repository.dart';

/// "Confirm booking" (mockup) — a real confirmation step between tapping
/// Accept on a bid and the actual accept API call, showing the job, the
/// transporter, and the price one more time before it's final. Unlike the
/// mockup, there's no separate "service fee" line here: this app's
/// commission is charged to the transporter, never the customer, so the
/// total is simply the agreed price — Cargo Motives never holds or takes
/// a cut of the customer's payment (the info banner below states exactly
/// that, and it's true regardless of which fee model is in place).
class BookingConfirmationScreen extends StatefulWidget {
  const BookingConfirmationScreen({super.key, required this.job, required this.bid, required this.bidRepository});

  final Job job;
  final Bid bid;
  final BidRepository bidRepository;

  @override
  State<BookingConfirmationScreen> createState() => _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  bool _isConfirming = false;
  String? _error;

  Future<void> _confirm() async {
    setState(() {
      _isConfirming = true;
      _error = null;
    });

    try {
      await widget.bidRepository.accept(widget.bid.id);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final bid = widget.bid;

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm booking')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(13),
                            color: AppColors.surfaceSubtle,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CM-${job.id.toString().padLeft(4, '0')}',
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: AppColors.textSecondary),
                                ),
                                Text(
                                  '${job.pickupAddress} → ${job.dropoffAddress}',
                                  style: const TextStyle(
                                    fontFamily: 'Barlow Condensed',
                                    fontSize: 21,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                Text(
                                  '${job.containerType} · ${job.containerSize}${job.approxWeightTons != null ? ' · ${job.approxWeightTons!.toStringAsFixed(0)} t' : ''}',
                                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          _Row(
                            label: 'Transporter',
                            value: bid.company.name,
                            trailingIcon: bid.company.verified ? Icons.check_circle : null,
                          ),
                          _Row(label: 'Pickup', value: DateFormat('d MMM, HH:mm').format(job.preferredPickupWindowStart)),
                          _Row(label: 'Verified trucks', value: '${bid.company.truckCount}', isLast: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                            color: AppColors.surfaceSubtle,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total',
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                                Text(
                                  'TZS ${bid.price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontFamily: 'Barlow Condensed',
                                    fontSize: 24,
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
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.infoTint,
                        border: Border.all(color: const Color(0xFFD6EBFF)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 16, color: AppColors.ctaBlue),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'You pay the transporter directly. Cargo Motives never holds your money — we only record the booking.',
                              style: TextStyle(fontSize: 12.5, color: AppColors.ctaBluePressed, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.red))],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isConfirming ? null : _confirm,
              child: _isConfirming
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('CONFIRM BOOKING'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.trailingIcon, this.isLast = false});

  final String label;
  final String value;
  final IconData? trailingIcon;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: isLast
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.background)),
            ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
              ),
              if (trailingIcon != null) ...[const SizedBox(width: 5), Icon(trailingIcon, size: 14, color: AppColors.statusLive)],
            ],
          ),
        ],
      ),
    );
  }
}
