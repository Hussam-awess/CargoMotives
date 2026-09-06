import 'package:flutter/material.dart';

import '../jobs/data/job_repository.dart';
import '../jobs/post_job_screen.dart';
import 'customer_jobs_tab.dart';
import 'customer_profile_tab.dart';

/// Customer Home (UI/UX Brief §3): Jobs (home) / Post / Profile — 3
/// bottom-nav items. "Post" isn't a persistent tab body (it's a one-shot
/// action, per AppFlow §3.1 — tapping it leads straight into the Post a
/// Job form): tapping it pushes PostJobScreen instead of switching the
/// IndexedStack, then returns to whichever tab was showing and refreshes
/// Jobs if a job was actually posted.
class CustomerHomeShell extends StatefulWidget {
  const CustomerHomeShell({super.key});

  @override
  State<CustomerHomeShell> createState() => _CustomerHomeShellState();
}

class _CustomerHomeShellState extends State<CustomerHomeShell> {
  /// Index into [_bodies] (0 = Jobs, 1 = Profile) — deliberately not the
  /// same as the NavigationBar's destination index, since "Post" (index 1
  /// there) never becomes a persistent selected body.
  int _bodyIndex = 0;
  final _jobsTabKey = GlobalKey<CustomerJobsTabState>();

  late final _bodies = [
    CustomerJobsTab(key: _jobsTabKey, repository: JobRepository()),
    CustomerProfileTab(),
  ];

  Future<void> _openPostJob() async {
    final posted = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => PostJobScreen()));
    if (posted == true) {
      _jobsTabKey.currentState?.refresh();
      setState(() => _bodyIndex = 0);
    }
  }

  void _onDestinationSelected(int destinationIndex) {
    switch (destinationIndex) {
      case 1:
        _openPostJob();
      case 2:
        setState(() => _bodyIndex = 1);
      default:
        setState(() => _bodyIndex = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _bodyIndex, children: _bodies),
      bottomNavigationBar: NavigationBar(
        // Post (index 1) is never the "selected" destination — it's a
        // one-shot action, not a body of its own.
        selectedIndex: _bodyIndex == 0 ? 0 : 2,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.work_outline), label: 'Jobs'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'Post'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
