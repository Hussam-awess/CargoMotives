import 'package:flutter/material.dart';

import '../jobs/data/job_repository.dart';
import '../jobs/job_detail_screen.dart';
import '../notifications/data/notification_repository.dart';
import '../notifications/notification_bell_button.dart';

/// Customer's Jobs (home) tab — AppFlow §3.1: the customer's own jobs,
/// tap through to a job's detail/bid list. Also this role's "home screen"
/// for the notification bell icon (AppFlow §3.1's own wording).
class CustomerJobsTab extends StatefulWidget {
  CustomerJobsTab({super.key, JobRepository? repository, NotificationRepository? notificationRepository})
    : repository = repository ?? JobRepository(),
      notificationRepository = notificationRepository ?? NotificationRepository();

  final JobRepository repository;
  final NotificationRepository notificationRepository;

  @override
  State<CustomerJobsTab> createState() => CustomerJobsTabState();
}

class CustomerJobsTabState extends State<CustomerJobsTab> {
  late Future<List<Job>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.list();
  }

  /// Called by CustomerHomeShell after a job is posted, so the list
  /// reflects it without the user needing to pull-to-refresh manually.
  void refresh() {
    // A block body, not an arrow — see NotificationsScreen._refresh()'s
    // comment (same Phase 2 setState-returns-a-Future gotcha; this method
    // had the bug latent and untested, since no existing test actually
    // taps the retry button, only checks it's present).
    setState(() {
      _future = widget.repository.list();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jobs'),
        actions: [
          NotificationBellButton(
            repository: widget.notificationRepository,
            onTapJob: (jobId) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: jobId))),
          ),
        ],
      ),
      body: FutureBuilder<List<Job>>(
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
                  const Text('Could not load your jobs.'),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: refresh, child: const Text('Try again')),
                ],
              ),
            );
          }

          final jobs = snapshot.data!;
          if (jobs.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => refresh(),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 80),
                  Icon(Icons.local_shipping_outlined, size: 48, color: Color(0xFF9E9E9E)),
                  SizedBox(height: 16),
                  Text('No jobs yet. Tap Post to create one.', textAlign: TextAlign.center),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => refresh(),
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
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: job.id)),
                      );
                      refresh();
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
