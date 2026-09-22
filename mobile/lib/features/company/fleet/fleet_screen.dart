import 'package:flutter/material.dart';

import '../data/driver_repository.dart';
import '../data/gps_repository.dart';
import '../data/truck_repository.dart';
import 'connect_gps_screen.dart';
import 'driver_list_tab.dart';
import 'fleet_map_screen.dart';
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
  GpsConnectionSummary? _activeConnection;

  @override
  void initState() {
    super.initState();
    _loadGpsConnectionStatus();
  }

  Future<void> _loadGpsConnectionStatus() async {
    try {
      final connections = await widget.gpsRepository.list();
      final connected = connections.where((c) => c.status == 'connected');
      if (!mounted) return;
      setState(() {
        _activeConnection = connected.isEmpty ? null : connected.first;
      });
    } catch (_) {
      // Non-critical — the app-bar action just falls back to "Connect GPS".
    }
  }

  Future<void> _openConnectGps() async {
    final connected = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ConnectGpsScreen(
          gpsRepository: widget.gpsRepository,
          truckRepository: widget.truckRepository,
        ),
      ),
    );
    if (connected == true) {
      _trucksTabKey.currentState?.refresh();
      _loadGpsConnectionStatus();
    }
  }

  Future<void> _disconnectGps() async {
    final connection = _activeConnection;
    if (connection == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect GPS?'),
        content: const Text(
          'Your fleet will stop showing live positions until you connect again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.gpsRepository.disconnect(connection.id);
      _trucksTabKey.currentState?.refresh();
      _loadGpsConnectionStatus();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not disconnect GPS. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _activeConnection != null;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Fleet'),
          actions: [
            IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      FleetMapScreen(repository: widget.truckRepository),
                ),
              ),
              icon: const Icon(Icons.map_outlined),
              tooltip: 'Fleet map',
            ),
            IconButton(
              onPressed: isConnected ? _disconnectGps : _openConnectGps,
              icon: Icon(
                isConnected ? Icons.link_off : Icons.satellite_alt_outlined,
              ),
              tooltip: isConnected ? 'Disconnect GPS' : 'Connect GPS',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Trucks'),
              Tab(text: 'Drivers'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            TruckListTab(
              key: _trucksTabKey,
              repository: widget.truckRepository,
            ),
            DriverListTab(repository: widget.driverRepository),
          ],
        ),
      ),
    );
  }
}
