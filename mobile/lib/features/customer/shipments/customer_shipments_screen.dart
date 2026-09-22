import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/job_views_badge.dart';
import '../../auth/data/auth_repository.dart';
import '../../jobs/data/job_repository.dart';
import '../../jobs/job_detail_screen.dart';
import '../../jobs/job_status.dart';

class _ShipmentsData {
  const _ShipmentsData({required this.jobs, required this.isFeatured});

  final List<Job> jobs;
  final bool isFeatured;
}

/// "My shipments" (mockup) — every shipment the customer has posted, not
/// just the one active one shown on the Home dashboard. Reached from
/// Home's "See all" links.
class CustomerShipmentsScreen extends StatefulWidget {
  CustomerShipmentsScreen({
    super.key,
    JobRepository? repository,
    AuthRepository? authRepository,
  }) : repository = repository ?? JobRepository(),
       authRepository = authRepository ?? AuthRepository();

  final JobRepository repository;
  final AuthRepository authRepository;

  @override
  State<CustomerShipmentsScreen> createState() =>
      _CustomerShipmentsScreenState();
}

class _CustomerShipmentsScreenState extends State<CustomerShipmentsScreen> {
  late Future<_ShipmentsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ShipmentsData> _load() async {
    final jobs = await widget.repository.list();
    // Only powers whether the job-views eye badge renders below — a
    // failed fetch just hides it rather than blocking the shipment list
    // itself, same non-critical pattern JobDetailScreen uses for the same
    // check.
    var isFeatured = false;
    try {
      isFeatured = (await widget.authRepository.me()).isFeatured;
    } catch (_) {
      // Non-critical — see comment above.
    }
    return _ShipmentsData(jobs: jobs, isFeatured: isFeatured);
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Shipments')),
      body: FutureBuilder<_ShipmentsData>(
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
                  const Text('Could not load your shipments.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _refresh,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          final jobs = data.jobs;
          if (jobs.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
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
                  Text('No shipments yet.', textAlign: TextAlign.center),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: jobs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final job = jobs[index];

                return _ShipmentTile(
                  job: job,
                  showViewsBadge: data.isFeatured,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => JobDetailScreen(jobId: job.id),
                      ),
                    );
                    _refresh();
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ShipmentTile extends StatelessWidget {
  const _ShipmentTile({
    required this.job,
    required this.onTap,
    required this.showViewsBadge,
  });

  final Job job;
  final VoidCallback onTap;

  /// Cargo Motives Plus benefit: whether the viewing customer is Plus —
  /// [Job.jobViewsCount] is a real count for every customer, but only a
  /// Plus customer actually sees the badge.
  final bool showViewsBadge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
          color: AppColors.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CM-${job.id.toString().padLeft(4, '0')}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Row(
                  children: [
                    if (showViewsBadge && job.jobViewsCount != null) ...[
                      JobViewsBadge(count: job.jobViewsCount!),
                      const SizedBox(width: 6),
                    ],
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
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: jobStatusColor(job.status),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${job.pickupAddress} → ${job.dropoffAddress}',
              style: TextStyle(
                fontFamily: 'Barlow Condensed',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${job.containerType} · ${job.containerSize}${job.assignedCompanyName != null ? ' · ${job.assignedCompanyName}' : ''}',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            if (job.status == 'completed' && job.completedAt != null) ...[
              const SizedBox(height: 3),
              Text(
                'Completed on ${DateFormat('d MMMM yyyy').format(job.completedAt!.toLocal())}',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
