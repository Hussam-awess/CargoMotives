import 'package:flutter/material.dart';

import '../data/driver_repository.dart';
import '../data/gps_repository.dart';
import '../data/truck_repository.dart';
import 'connect_gps_screen.dart';
import 'driver_list_tab.dart';
import 'truck_list_tab.dart';

/// Fleet (UI/UX Brief §3): trucks and the driver roster as top-level tabs
/// within the Fleet bottom-nav item — not separate bottom-nav entries,
/// matching the brief's "keep each shell to 3-4 bottom-nav items" rule.
/// Connect GPS (Phase 6) lives here too, as an app-bar action rather than
/// a third tab — it's a one-shot setup action, not an ongoing view, the
/// same reasoning CustomerHomeShell applied to "Post".
class FleetScreen extends StatefulWidget {
  FleetScreen({
    super.key,
    TruckRepository? truckRepository,
    DriverRepository? driverRepository,
    GpsRepository? gpsRepository,
  }) : truckRepository = truckRepository ?? TruckRepository(),
       driverRepository = driverRepository ?? DriverRepository(),
       gpsRepository = gpsRepository ?? GpsRepository();

  final TruckRepository truckRepository;
  final DriverRepository driverRepository;
  final GpsRepository gpsRepository;

  @override
  State<FleetScreen> createState() => _FleetScreenState();
}

class _FleetScreenState extends State<FleetScreen> {
  final _trucksTabKey = GlobalKey<TruckListTabState>();

  Future<void> _openConnectGps() async {
    final connected = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ConnectGpsScreen(gpsRepository: widget.gpsRepository, truckRepository: widget.truckRepository)),
    );
    if (connected == true) _trucksTabKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Fleet'),
          actions: [IconButton(onPressed: _openConnectGps, icon: const Icon(Icons.satellite_alt_outlined), tooltip: 'Connect GPS')],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Trucks'),
              Tab(text: 'Drivers'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            TruckListTab(key: _trucksTabKey, repository: widget.truckRepository),
            DriverListTab(repository: widget.driverRepository),
          ],
        ),
      ),
    );
  }
}
