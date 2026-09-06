import 'package:flutter/material.dart';

import '../data/driver_repository.dart';
import 'add_driver_screen.dart';

/// "Fleet -> Drivers: simple roster" — AppFlow §2.2.
class DriverListTab extends StatefulWidget {
  DriverListTab({super.key, DriverRepository? repository})
    : repository = repository ?? DriverRepository();

  final DriverRepository repository;

  @override
  State<DriverListTab> createState() => _DriverListTabState();
}

class _DriverListTabState extends State<DriverListTab> {
  late Future<List<Driver>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.list();
  }

  Future<void> _refresh() async {
    final future = widget.repository.list();
    setState(() => _future = future);
    await future;
  }

  Future<void> _openAddDriver({Driver? edit}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            AddDriverScreen(repository: widget.repository, editDriver: edit),
      ),
    );
    if (saved == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Driver>>(
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
                  const Text('Could not load your drivers.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _refresh,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            );
          }

          final drivers = snapshot.data!;
          if (drivers.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 80),
                  Icon(
                    Icons.badge_outlined,
                    size: 48,
                    color: Color(0xFF9E9E9E),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No drivers yet. Tap + to add one.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: drivers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final driver = drivers[index];

                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(driver.fullName),
                    subtitle: Text(driver.phoneNumber),
                    onTap: () => _openAddDriver(edit: driver),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddDriver(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
