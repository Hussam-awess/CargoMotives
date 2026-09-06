import 'package:flutter/material.dart';

import '../data/driver_repository.dart';
import '../data/truck_repository.dart';
import 'driver_list_tab.dart';
import 'truck_list_tab.dart';

/// Fleet (UI/UX Brief §3): trucks and the driver roster as top-level tabs
/// within the Fleet bottom-nav item — not separate bottom-nav entries,
/// matching the brief's "keep each shell to 3-4 bottom-nav items" rule.
class FleetScreen extends StatelessWidget {
  FleetScreen({
    super.key,
    TruckRepository? truckRepository,
    DriverRepository? driverRepository,
  }) : truckRepository = truckRepository ?? TruckRepository(),
       driverRepository = driverRepository ?? DriverRepository();

  final TruckRepository truckRepository;
  final DriverRepository driverRepository;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Fleet'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Trucks'),
              Tab(text: 'Drivers'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            TruckListTab(repository: truckRepository),
            DriverListTab(repository: driverRepository),
          ],
        ),
      ),
    );
  }
}
