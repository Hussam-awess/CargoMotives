import 'package:flutter/material.dart';

import '../../jobs/data/company_job_repository.dart';
import '../data/featured_repository.dart';
import 'job_list_view.dart';

/// Company Jobs (UI/UX Brief §3): Open / My Bids / Active as top-level
/// tabs within the Jobs bottom-nav item — same "tabs, not separate
/// bottom-nav entries" pattern as FleetScreen's Trucks/Drivers split.
/// Featured companies additionally see a route-filter toggle on Open
/// (AppFlow §2.7) — fetched once so a non-Featured company never sees a
/// control that would silently do nothing for them.
class CompanyJobsScreen extends StatefulWidget {
  CompanyJobsScreen({super.key, CompanyJobRepository? repository, CompanyFeaturedRepository? featuredRepository})
    : repository = repository ?? CompanyJobRepository(),
      featuredRepository = featuredRepository ?? CompanyFeaturedRepository();

  final CompanyJobRepository repository;
  final CompanyFeaturedRepository featuredRepository;

  @override
  State<CompanyJobsScreen> createState() => _CompanyJobsScreenState();
}

class _CompanyJobsScreenState extends State<CompanyJobsScreen> {
  bool _isFeatured = false;
  bool _usePreferredRoutes = false;

  @override
  void initState() {
    super.initState();
    _checkFeaturedStatus();
  }

  Future<void> _checkFeaturedStatus() async {
    try {
      final status = await widget.featuredRepository.status();
      if (mounted) setState(() => _isFeatured = status.isFeatured);
    } catch (_) {
      // A non-Featured company (or a failed check) just doesn't see the
      // toggle — this is a convenience filter, not core functionality.
    }
  }

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
            Column(
              children: [
                if (_isFeatured)
                  SwitchListTile(
                    title: const Text('My preferred routes only'),
                    value: _usePreferredRoutes,
                    onChanged: (value) => setState(() => _usePreferredRoutes = value),
                  ),
                Expanded(
                  child: JobListView(
                    key: ValueKey(_usePreferredRoutes),
                    loader: () => widget.repository.open(usePreferredRoutes: _usePreferredRoutes),
                    emptyMessage: _usePreferredRoutes ? 'No open jobs on your preferred routes right now.' : 'No open jobs right now.',
                  ),
                ),
              ],
            ),
            JobListView(loader: widget.repository.myBids, emptyMessage: "You haven't placed any bids yet."),
            JobListView(loader: widget.repository.active, emptyMessage: 'No active jobs yet.'),
          ],
        ),
      ),
    );
  }
}
