import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'data/follow_repository.dart';

/// The "Following" list (Phase: Follow system) — every customer this
/// company currently follows, i.e. whose new job postings trigger a
/// notification (JobObserver::created()). Unfollowing here has the same
/// effect as unfollowing from a job's detail screen.
class FollowedCustomersScreen extends StatefulWidget {
  FollowedCustomersScreen({super.key, FollowRepository? repository}) : repository = repository ?? FollowRepository();

  final FollowRepository repository;

  @override
  State<FollowedCustomersScreen> createState() => _FollowedCustomersScreenState();
}

class _FollowedCustomersScreenState extends State<FollowedCustomersScreen> {
  late Future<List<FollowedCustomer>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.list();
  }

  void _refresh() {
    setState(() {
      _future = widget.repository.list();
    });
  }

  Future<void> _unfollow(FollowedCustomer customer) async {
    try {
      await widget.repository.unfollow(customer.id);
      if (mounted) _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not unfollow this customer.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Following')),
      body: FutureBuilder<List<FollowedCustomer>>(
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
                  const Text('Could not load followed customers.'),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _refresh, child: const Text('Try again')),
                ],
              ),
            );
          }

          final customers = snapshot.data!;
          if (customers.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 80),
                  Icon(Icons.person_add_alt_outlined, size: 48, color: AppColors.textTertiary),
                  const SizedBox(height: 16),
                  const Text("You're not following any customers yet.", textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text(
                    'Follow a customer from one of their jobs to get notified when they post a new one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: customers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final customer = customers[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(customer.displayName, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                      ),
                      TextButton(onPressed: () => _unfollow(customer), child: const Text('Unfollow')),
                    ],
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
