import 'package:flutter/material.dart';

import '../../jobs/data/company_job_repository.dart';
import 'job_list_view.dart';

/// Company Jobs (UI/UX Brief §3): Open / My Bids / Active as top-level
/// tabs within the Jobs bottom-nav item — same "tabs, not separate
/// bottom-nav entries" pattern as FleetScreen's Trucks/Drivers split.
class CompanyJobsScreen extends StatelessWidget {
  CompanyJobsScreen({super.key, CompanyJobRepository? repository}) : repository = repository ?? CompanyJobRepository();

  final CompanyJobRepository repository;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Jobs'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Open'),
              Tab(text: 'My Bids'),
              Tab(text: 'Active'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            JobListView(loader: repository.open, emptyMessage: 'No open jobs right now.'),
            JobListView(loader: repository.myBids, emptyMessage: "You haven't placed any bids yet."),
            JobListView(loader: repository.active, emptyMessage: 'No active jobs yet.'),
          ],
        ),
      ),
    );
  }
}
