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
  const JobListView({super.key, required this.loader, required this.emptyMessage});

  final Future<List<Job>> Function() loader;
  final String emptyMessage;

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
    setState(() => _future = future);
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
                const Icon(Icons.work_outline, size: 48, color: AppColors.textTertiary),
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
  const _JobBoardCard({required this.job, required this.onTap});

  final Job job;
  final VoidCallback onTap;

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
          border: Border.all(color: const Color(0xFFE4E5E8)),
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
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${job.pickupAddress} → ${job.dropoffAddress}',
                        style: const TextStyle(fontFamily: 'Barlow Condensed', fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                      Text(
                        '${job.containerType} · ${job.containerSize}${job.approxWeightTons != null ? ' · ${job.approxWeightTons!.toStringAsFixed(0)} t' : ''}',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
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
                        style: const TextStyle(fontFamily: 'Barlow Condensed', fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                      Text(job.currency, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  )
                else if (job.isOpen)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${job.bidsCount ?? 0}',
                        style: const TextStyle(fontFamily: 'Barlow Condensed', fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                      const Text('bids so far', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
              ],
            ),
            Container(
              margin: const EdgeInsets.only(top: 11),
              padding: const EdgeInsets.only(top: 11),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF2F2F3)))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pickup ${DateFormat('d MMM, HH:mm').format(job.preferredPickupWindowStart)}'
                    '${distance != null ? ' · ${distance.toStringAsFixed(0)} km' : ''}',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                  Text(
                    job.isOpen ? 'Place bid' : jobStatusLabel(job.status),
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: job.isOpen ? AppColors.ctaBlue : jobStatusColor(job.status)),
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
