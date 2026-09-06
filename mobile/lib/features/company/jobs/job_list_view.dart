import 'package:flutter/material.dart';

import '../../jobs/data/job_repository.dart';
import 'company_job_detail_screen.dart';

/// The shared rendering for all three Jobs-home tabs (Open/My Bids/Active)
/// — same list/empty/error/refresh shape, different data source per tab
/// (CompanyJobRepository.open/myBids/active), so this exists once instead
/// of being copy-pasted three times.
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
                const Icon(Icons.work_outline, size: 48, color: Color(0xFF9E9E9E)),
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
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final job = jobs[index];

              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  title: Text('${job.containerType} · ${job.containerSize}'),
                  subtitle: Text('${job.pickupAddress} → ${job.dropoffAddress}'),
                  trailing: Text(job.status),
                  onTap: () async {
                    await Navigator.of(
                      context,
                    ).push(MaterialPageRoute(builder: (_) => CompanyJobDetailScreen(jobId: job.id)));
                    _refresh();
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}
