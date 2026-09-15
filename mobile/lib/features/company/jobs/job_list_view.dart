import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../jobs/data/job_repository.dart';
import '../../jobs/job_geo.dart';
import '../../jobs/job_status.dart';
import 'company_job_detail_screen.dart';

/// The shared rendering for all three Jobs-home tabs (Open/My Bids/Active)
/// — same list/empty/error/refresh shape, different data source per tab
/// (CompanyJobRepository.open/myBids/active), so this exists once instead
/// of being copy-pasted three times. Restyled to the mockup's "Cargo job
/// board" card — price is deliberately omitted for open jobs (there is no
/// agreed price before a bid is accepted; showing the bid count instead is
/// the real number a transporter cares about here).
class JobListView extends StatefulWidget {
  const JobListView({super.key, required this.loader, required this.emptyMessage, this.showCustomerTrustSignal = false});

  final Future<List<Job>> Function() loader;
  final String emptyMessage;

  /// Company Plus benefit (Phase 10.19): shows the posting customer's real
  /// completed-shipment count on each card — only meaningful (and only
  /// populated by the backend) on the Open tab, and only worth showing to
  /// a Featured company, per CompanyJobsScreen's own _isFeatured check.
  final bool showCustomerTrustSignal;

  @override
  State<JobListView> createState() => _JobListViewState();
}

class _JobListViewState extends State<JobListView> {
  late Future<List<Job>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  Future<void> _refresh() async {
    final future = widget.loader();
    // A block body, not an arrow (`() => _future = ...`) — an arrow
    // closure's value IS the assignment's value (a Future here), and
    // Flutter's setState() explicitly rejects a callback that returns one.
    // In a release build this assert is stripped and the assignment still
    // takes effect harmlessly, but in debug (e.g. `flutter run` without
    // --release) every pull-to-refresh here threw and never updated the
    // list — the likely real cause behind "Find Jobs doesn't work".
    setState(() {
      _future = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Job>>(
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
                const Text('Could not load jobs.'),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _refresh, child: const Text('Try again')),
              ],
            ),
          );
        }

        final jobs = snapshot.data!;
        if (jobs.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 80),
                Icon(Icons.work_outline, size: 48, color: AppColors.textTertiary),
                const SizedBox(height: 16),
                Text(widget.emptyMessage, textAlign: TextAlign.center),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: jobs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final job = jobs[index];

              return _JobBoardCard(
                job: job,
                showCustomerTrustSignal: widget.showCustomerTrustSignal,
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CompanyJobDetailScreen(jobId: job.id)));
                  _refresh();
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _JobBoardCard extends StatelessWidget {
  const _JobBoardCard({required this.job, required this.onTap, this.showCustomerTrustSignal = false});

  final Job job;
  final VoidCallback onTap;
  final bool showCustomerTrustSignal;

  @override
  Widget build(BuildContext context) {
    final distance = (job.pickupLat != null && job.pickupLng != null && job.dropoffLat != null && job.dropoffLng != null)
        ? kmBetween(job.pickupLat!, job.pickupLng!, job.dropoffLat!, job.dropoffLng!)
        : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Color(0x0D1D2D3D), blurRadius: 2, offset: Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CM-${job.id.toString().padLeft(4, '0')}',
                        style: TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${job.pickupAddress} → ${job.dropoffAddress}',
                        style: TextStyle(
                          fontFamily: 'Barlow Condensed',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        '${job.containerType} · ${job.containerSize}${job.approxWeightTons != null ? ' · ${job.approxWeightTons!.toStringAsFixed(0)} t' : ''}'
                        '${job.isOpen ? ' · ${job.bidsCount ?? 0} bid${job.bidsCount == 1 ? '' : 's'}' : ''}',
                        style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (job.agreedPrice != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        job.agreedPrice!.toStringAsFixed(0),
                        style: TextStyle(
                          fontFamily: 'Barlow Condensed',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(job.currency, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  )
                else if (job.isOpen && job.budgetPrice != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        job.budgetPrice!.toStringAsFixed(0),
                        style: TextStyle(
                          fontFamily: 'Barlow Condensed',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      Text('${job.currency} budget', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  )
                else if (job.isOpen)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${job.bidsCount ?? 0}',
                        style: TextStyle(
                          fontFamily: 'Barlow Condensed',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      Text('bids so far', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
              ],
            ),
            if (showCustomerTrustSignal && job.customerCompletedJobsCount != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.verified_outlined, size: 13, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Text(
                    '${job.customerCompletedJobsCount} completed shipment${job.customerCompletedJobsCount == 1 ? '' : 's'} on Cargo Motives',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
            Container(
              margin: const EdgeInsets.only(top: 11),
              padding: const EdgeInsets.only(top: 11),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.background)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pickup ${DateFormat('d MMM, HH:mm').format(job.preferredPickupWindowStart)}'
                    '${distance != null ? ' · ${distance.toStringAsFixed(0)} km' : ''}',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                  Text(
                    job.isOpen ? 'Place bid' : jobStatusLabel(job.status),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: job.isOpen ? AppColors.ctaBlue : jobStatusColor(job.status),
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
