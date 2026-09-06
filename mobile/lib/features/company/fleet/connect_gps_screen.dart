import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../data/gps_repository.dart';
import '../data/truck_repository.dart';

/// Connect GPS (AppFlow §2.3): pick a provider, authorize with an access
/// token, then match each returned vehicle to a registered truck (or skip
/// it — an unmatched vehicle just stays "GPS Tracking Not Available",
/// same as if the company never connected anything at all). Only Wialon
/// is a real integration yet (Phase 6 — "prove the pattern with one
/// provider before touching a second"); the others are shown so the
/// picker matches the UI/UX Brief's mockup, but disabled.
class ConnectGpsScreen extends StatefulWidget {
  ConnectGpsScreen({super.key, GpsRepository? gpsRepository, TruckRepository? truckRepository})
    : gpsRepository = gpsRepository ?? GpsRepository(),
      truckRepository = truckRepository ?? TruckRepository();

  final GpsRepository gpsRepository;
  final TruckRepository truckRepository;

  @override
  State<ConnectGpsScreen> createState() => _ConnectGpsScreenState();
}

class _ConnectGpsScreenState extends State<ConnectGpsScreen> {
  final _tokenController = TextEditingController();
  bool _isConnecting = false;
  String? _connectError;

  GpsConnectionSummary? _connection;
  List<GpsUnitCandidate> _units = [];
  List<Truck> _availableTrucks = [];
  final Map<String, int?> _selectedTruckIdByUnit = {};
  bool _isImporting = false;
  String? _importError;
  List<Truck>? _importedTrucks;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() => _connectError = 'Enter your Wialon API token.');
      return;
    }

    setState(() {
      _isConnecting = true;
      _connectError = null;
    });

    try {
      final result = await widget.gpsRepository.connect(provider: 'wialon', accessToken: token);
      final trucks = await widget.truckRepository.list();
      if (!mounted) return;
      setState(() {
        _connection = result.connection;
        _units = result.units;
        _availableTrucks = trucks.where((t) => t.gpsStatus != 'connected').toList();
        for (final unit in result.units) {
          _selectedTruckIdByUnit[unit.unitId] = unit.suggestedTruckId;
        }
      });
    } on ApiException catch (e) {
      setState(() => _connectError = e.firstErrorFor('access_token') ?? e.message);
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _import() async {
    final matches = <String, int>{
      for (final entry in _selectedTruckIdByUnit.entries)
        if (entry.value != null) entry.key: entry.value!,
    };

    if (matches.isEmpty) {
      setState(() => _importError = 'Match at least one vehicle to a truck, or go back if none apply.');
      return;
    }

    setState(() {
      _isImporting = true;
      _importError = null;
    });

    try {
      final trucks = await widget.gpsRepository.import(connectionId: _connection!.id, unitIdToTruckId: matches);
      if (!mounted) return;
      setState(() => _importedTrucks = trucks);
    } on ApiException catch (e) {
      setState(() => _importError = e.message);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect GPS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _importedTrucks != null
            ? _ImportedSummary(trucks: _importedTrucks!, onDone: () => Navigator.of(context).pop(true))
            : _connection == null
            ? _ProviderForm(
                tokenController: _tokenController,
                isConnecting: _isConnecting,
                error: _connectError,
                onConnect: _connect,
              )
            : _MatchUnitsForm(
                units: _units,
                availableTrucks: _availableTrucks,
                selectedTruckIdByUnit: _selectedTruckIdByUnit,
                onSelect: (unitId, truckId) => setState(() => _selectedTruckIdByUnit[unitId] = truckId),
                isImporting: _isImporting,
                error: _importError,
                onImport: _import,
              ),
      ),
    );
  }
}

class _ProviderForm extends StatelessWidget {
  const _ProviderForm({required this.tokenController, required this.isConnecting, required this.error, required this.onConnect});

  final TextEditingController tokenController;
  final bool isConnecting;
  final String? error;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Choose your provider', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        const _ProviderTile(name: 'Wialon', enabled: true, selected: true),
        const SizedBox(height: 8),
        const _ProviderTile(name: 'Traccar', enabled: false, selected: false),
        const SizedBox(height: 8),
        const _ProviderTile(name: 'Tracksolid Pro', enabled: false, selected: false),
        const SizedBox(height: 24),
        TextField(
          controller: tokenController,
          decoration: const InputDecoration(labelText: 'Wialon API token'),
          obscureText: true,
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: isConnecting ? null : onConnect,
          child: isConnecting
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Connect'),
        ),
      ],
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.name, required this.enabled, required this.selected});

  final String name;
  final bool enabled;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Card(
        margin: EdgeInsets.zero,
        color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
        child: ListTile(
          title: Text(name),
          trailing: enabled ? null : const Text('Coming soon', style: TextStyle(color: Color(0xFF6B7280))),
        ),
      ),
    );
  }
}

class _MatchUnitsForm extends StatelessWidget {
  const _MatchUnitsForm({
    required this.units,
    required this.availableTrucks,
    required this.selectedTruckIdByUnit,
    required this.onSelect,
    required this.isImporting,
    required this.error,
    required this.onImport,
  });

  final List<GpsUnitCandidate> units;
  final List<Truck> availableTrucks;
  final Map<String, int?> selectedTruckIdByUnit;
  final void Function(String unitId, int? truckId) onSelect;
  final bool isImporting;
  final String? error;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('✓ Wialon connected', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.green)),
        const SizedBox(height: 4),
        Text('We found ${units.length} vehicle(s)', style: const TextStyle(color: Color(0xFF6B7280))),
        const SizedBox(height: 16),
        for (final unit in units) ...[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(unit.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (!unit.hasPosition)
                          const Text('No position reported yet', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                      ],
                    ),
                  ),
                  DropdownButton<int?>(
                    value: selectedTruckIdByUnit[unit.unitId],
                    hint: const Text('Skip'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Skip')),
                      for (final truck in availableTrucks)
                        DropdownMenuItem<int?>(value: truck.id, child: Text(truck.registrationNumber)),
                    ],
                    onChanged: (truckId) => onSelect(unit.unitId, truckId),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: isImporting ? null : onImport,
          child: isImporting
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Import selected vehicles'),
        ),
      ],
    );
  }
}

class _ImportedSummary extends StatelessWidget {
  const _ImportedSummary({required this.trucks, required this.onDone});

  final List<Truck> trucks;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 48),
        const SizedBox(height: 12),
        Text('${trucks.length} truck(s) connected', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        for (final truck in trucks) Text(truck.registrationNumber, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: onDone, child: const Text('Done')),
      ],
    );
  }
}
